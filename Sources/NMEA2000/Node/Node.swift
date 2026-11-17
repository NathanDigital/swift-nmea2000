// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A device on an NMEA 2000 bus: it opens a CAN transport, claims an address,
/// sends messages and delivers the messages it receives.
///
/// Create a node with a transport, start ``run()`` in a task, and read
/// ``messages()``:
///
/// ```swift
/// let node = Node(transport: transport, mode: .node, name: myName)
/// Task { try await node.run() }
/// for await message in await node.messages() {
///   if message.pgn == PositionRapidUpdate.pgn {
///     let position = try PositionRapidUpdate(message)
///   }
/// }
/// ```
///
/// When the transport opens, the node waits 200 ms and then claims its
/// address. While the claim is in progress (250 ms, longer if another device
/// contests the address) sending throws ``NodeError/claimingAddress``.
///
/// Ports `tNMEA2000` for one device: the open sequence, sending, receiving
/// and address claiming. Upstream calls message handlers from
/// `ParseMessages`, which the application calls in its main loop; here
/// ``run()`` handles frames as they arrive and ``messages()`` delivers them.
public actor Node {
  /// How a node takes part in the bus.
  ///
  /// Upstream has five modes. Pairs of them differ only in whether messages
  /// are forwarded to a stream, which isn't part of this type, so they map
  /// onto three.
  public enum Mode: Sendable, Hashable {
    /// Receives messages and never sends any (upstream's `N2km_ListenOnly`).
    case listenOnly

    /// Receives and sends messages without claiming an address (upstream's
    /// `N2km_SendOnly` and `N2km_ListenAndSend`). The address must not be
    /// used by another device.
    case listenAndSend

    /// A full node: claims an address and defends it, answers ISO requests
    /// and group functions, and sends heartbeats (upstream's
    /// `N2km_NodeOnly` and `N2km_ListenAndNode`).
    case node
  }

  /// A device the node hosts on the bus.
  ///
  /// Most nodes host one device. A node can host several, as upstream's
  /// `SetDeviceCount` allows, each with its own address, NAME and
  /// heartbeat; they share the transport and the configuration
  /// information.
  public struct Device: Sendable, Hashable {
    /// The address to claim first. If another device holds it, the device
    /// tries the following addresses, skipping its sibling devices'. 254
    /// starts from 14. Save it when it changes and use it next time, so the
    /// device keeps its address across restarts.
    public var address: UInt8

    /// The NAME to claim the address with. Every device on a bus needs a
    /// different NAME.
    public var name: DeviceName

    /// The product information the device sends when asked, or `nil` for
    /// the first device's.
    public var productInformation: ProductInformation?

    /// The PGNs the device sends, beyond the network management PGNs every
    /// node sends. The device lists them when asked.
    public var transmitPGNs: [UInt32]

    /// The PGNs the device receives, beyond the network management PGNs.
    /// The device lists them when asked.
    public var receivePGNs: [UInt32]

    /// How often to send a heartbeat, between 1 and 655.32 seconds, or `nil`
    /// for none. The first is sent 10 seconds after the node opens.
    public var heartbeatInterval: Duration?

    /// Creates a device.
    ///
    /// - Parameters:
    ///   - address: The address to claim first.
    ///   - name: The NAME to claim the address with, which must differ from
    ///     every other device's on the bus.
    ///   - productInformation: The product information the device sends
    ///     when asked, or `nil` for the first device's, which needs its own.
    ///   - transmitPGNs: The PGNs the device sends.
    ///   - receivePGNs: The PGNs the device receives.
    ///   - heartbeatInterval: How often to send a heartbeat, or `nil` for
    ///     none.
    public init(
      address: UInt8 = 15,
      name: DeviceName,
      productInformation: ProductInformation?,
      transmitPGNs: [UInt32] = [],
      receivePGNs: [UInt32] = [],
      heartbeatInterval: Duration? = .seconds(60)
    ) {
      self.address = address
      self.name = name
      self.productInformation = productInformation
      self.transmitPGNs = transmitPGNs
      self.receivePGNs = receivePGNs
      self.heartbeatInterval = heartbeatInterval
    }
  }

  /// Identifies one of the devices a node hosts, by its position in the
  /// devices the node was created with. The first device is ``first``, or
  /// `0`.
  public struct DeviceID: RawRepresentable, Hashable, Sendable, Codable,
    ExpressibleByIntegerLiteral, CustomStringConvertible
  {
    /// The device's position in the node's devices.
    public var rawValue: Int

    /// Creates the identifier of the device at a position.
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    /// Creates the identifier of the device at a position.
    public init(integerLiteral value: Int) {
      self.init(rawValue: value)
    }

    /// The first device, which most nodes host alone.
    public static let first = DeviceID(rawValue: 0)

    public var description: String { "device \(rawValue)" }
  }

  /// An ISO request for a PGN the node doesn't answer itself.
  public struct PGNRequest: Sendable, Hashable {
    /// The PGN asked for.
    public var pgn: UInt32
    /// The requester's address.
    public var requester: UInt8
    /// The node's device the request is for.
    public var device: DeviceID
    /// Whether the request was broadcast, so that every device is asked in
    /// turn and none answers with a negative acknowledgement.
    public var isBroadcast: Bool

    /// Creates a request.
    public init(pgn: UInt32, requester: UInt8, device: DeviceID, isBroadcast: Bool) {
      self.pgn = pgn
      self.requester = requester
      self.device = device
      self.isBroadcast = isBroadcast
    }
  }

  /// Answers an ISO request for a PGN the node doesn't answer itself.
  ///
  /// The handler returns the messages the device sends in reply, or `nil`
  /// if it doesn't handle the PGN; the device then sends a negative
  /// acknowledgement if the request was addressed to it.
  ///
  /// Handlers are synchronous because the node answers while it handles
  /// the request's frame, before the next one, as upstream does; an
  /// `await` there would let other frames through first. Keep what a
  /// handler needs where it can read it at once, such as in a
  /// `Mutex`-protected value that the rest of the app updates.
  ///
  /// Replaces upstream's `SetISORqstHandler` callback.
  public typealias ISORequestHandler = @Sendable (PGNRequest) -> [Message]?

  /// Answers group functions (PGN 126208) for a PGN, as an upstream
  /// `tN2kGroupFunctionHandler` subclass does.
  ///
  /// The handler gets the request and returns the messages its device sends
  /// in reply, usually a ``GroupFunction/Acknowledgement`` or a
  /// ``GroupFunction/Reply``, or `nil` to let the node answer as it does
  /// without a handler, which upstream's subclasses get by calling the base
  /// class. The handler sees broadcast commands, reads and writes too,
  /// which upstream ignores. Like ``ISORequestHandler``, it's synchronous.
  public typealias GroupFunctionHandler = @Sendable (GroupFunction.Request) -> [Message]?

  /// Something that happened to the node, from ``events()``.
  ///
  /// Replaces upstream's `SetOnOpen` callback and its `ReadResetAddressChanged`,
  /// `ReadResetDeviceInformationChanged` and
  /// `ReadResetInstallationDescriptionChanged` flags.
  public enum Event: Sendable, Hashable {
    /// The transport opened and the devices started claiming their
    /// addresses. Sending is possible once a claim ends, 250 ms later; see
    /// ``Node/waitUntilReady(_:)``.
    case opened
    /// A device's address claim ended with the address it now holds, so it
    /// can send.
    case addressClaimed(device: DeviceID, address: UInt8)
    /// A device found no free address, so it can't send.
    case addressClaimFailed(device: DeviceID)
    /// A device moved to another address. Save ``Node/devices`` so the
    /// device starts from it next time.
    case addressChanged(device: DeviceID)
    /// A device's NAME or heartbeat interval changed, from a clash with an
    /// identical device or another device's group function command.
    case deviceInformationChanged(device: DeviceID)
    /// Another device changed the installation descriptions in
    /// ``Node/configurationInformation`` with a group function command.
    case installationDescriptionChanged
  }

  /// How the node takes part in the bus.
  public nonisolated let mode: Mode

  /// The most frames the node queues to send before it drops the frames it
  /// sends on its own, as upstream's send frame buffer holds 40 by default
  /// (`SetN2kCANSendFrameBufSize`). Messages sent with ``send(_:from:)``
  /// wait for the transport instead.
  static let maxQueuedFrames = 40

  private var engine: NodeEngine
  private let clock: NodeClock
  private let openTransport: @Sendable () async throws -> FrameSource
  private let sendFrame: @Sendable (CANFrame) async throws -> Void
  private var subscribers:
    [Int: (continuation: AsyncStream<Message>.Continuation, includesSent: Bool)] =
      [:]
  private var eventSubscribers: [Int: AsyncStream<Event>.Continuation] = [:]
  private var nextSubscriberID = 0
  /// Tasks waiting in ``waitUntilReady(_:)`` for the engine to change.
  private var stateWaiters: [Int: CheckedContinuation<Void, any Error>] = [:]
  private var lastTransmission: Task<Void, any Error>?
  /// How many frames are queued to send and not yet sent.
  private var queuedFrameCount = 0
  private var timer: Task<Void, Never>?
  private var timerDeadline: UInt64?
  private var isRunning = false
  /// Whether ``run()`` has returned since it last started.
  private var hasStopped = false

  /// How a node takes part in the bus, and the devices it hosts.
  ///
  /// Start from ``node(_:configurationInformation:)``,
  /// ``listenOnly()`` or ``listenAndSend(address:)``, and change the other
  /// properties as needed.
  ///
  /// Replaces upstream's settings before `Open`: `SetMode`, `SetN2kSource`,
  /// `SetDeviceCount`, `SetDeviceInformation`, `SetProductInformation`,
  /// `SetConfigurationInformation`, `Extend…Messages`,
  /// `SetHandleOnlyKnownMessages` and `SetN2kCANMsgBufSize`.
  public struct Configuration: Sendable {
    /// How the node takes part in the bus.
    public var mode: Mode

    /// The devices the node hosts, at least one. Most nodes host one.
    public var devices: [Device]

    /// The configuration information the devices send when asked, or `nil`
    /// to refuse requests for it.
    public var configurationInformation: ConfigurationInformation?

    /// Which PGNs are sent and received as fast packets.
    public var catalog = PGNCatalog()

    /// Whether to drop received messages whose PGN isn't in the catalog.
    public var handlesOnlyKnownMessages = false

    /// How many fast packets and transport protocol sessions can be
    /// reassembled at once. Upstream defaults to 5 (`SetN2kCANMsgBufSize`).
    public var bufferCount = 5

    /// Whether to keep a ``DeviceList`` of the devices on the bus, asking
    /// them for their details as upstream's `tN2kDeviceList` does. The
    /// first device asks.
    public var discoversDevices = false

    /// Creates a configuration.
    public init(
      mode: Mode, devices: [Device], configurationInformation: ConfigurationInformation? = nil
    ) {
      precondition(!devices.isEmpty, "A node hosts at least one device")
      precondition(
        mode != .node || devices[0].productInformation != nil,
        "A full node's first device needs product information")
      self.mode = mode
      self.devices = devices
      self.configurationInformation = configurationInformation
    }

    /// A full node hosting one device: it claims an address, answers
    /// requests and group functions, and sends heartbeats.
    ///
    /// - Parameters:
    ///   - device: The device, with its own NAME and product information.
    ///   - configurationInformation: The configuration information the
    ///     device sends when asked, or `nil` to refuse requests for it.
    public static func node(
      _ device: Device, configurationInformation: ConfigurationInformation?
    ) -> Configuration {
      Configuration(
        mode: .node, devices: [device], configurationInformation: configurationInformation)
    }

    /// A node that only receives, such as a logger or display.
    public static func listenOnly() -> Configuration {
      Configuration(mode: .listenOnly, devices: [Device(name: .default, productInformation: nil)])
    }

    /// A node that receives, and sends from an address it doesn't claim,
    /// which no other device on the bus may use.
    public static func listenAndSend(address: UInt8) -> Configuration {
      Configuration(
        mode: .listenAndSend,
        devices: [Device(address: address, name: .default, productInformation: nil)])
    }
  }

  /// Creates a node.
  ///
  /// ```swift
  /// let device = Node.Device(
  ///   name: DeviceName(uniqueNumber: 7, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25),
  ///   productInformation: myProductInformation)
  /// let node = Node(
  ///   transport: transport,
  ///   configuration: .node(device, configurationInformation: myConfigurationInformation))
  /// ```
  ///
  /// - Parameters:
  ///   - transport: The CAN bus connection.
  ///   - configuration: How the node takes part in the bus, and its devices.
  ///   - clock: The clock that times the open sequence, address claims and
  ///     heartbeats.
  public init(
    transport: some CANTransport,
    configuration: Configuration,
    clock: some Clock<Duration> = ContinuousClock()
  ) {
    let mode = configuration.mode
    let devices = configuration.devices
    let catalog = configuration.catalog
    let handlesOnlyKnownMessages = configuration.handlesOnlyKnownMessages
    let bufferCount = configuration.bufferCount
    let configurationInformation = configuration.configurationInformation
    let discoversDevices = configuration.discoversDevices
    self.mode = mode
    engine = NodeEngine(
      mode: mode, devices: devices, catalog: catalog,
      handlesOnlyKnownMessages: handlesOnlyKnownMessages, bufferCount: bufferCount,
      configurationInformation: configurationInformation)
    if discoversDevices { engine.deviceList = DeviceList() }
    self.clock = NodeClock(clock)
    openTransport = {
      let frames = try await transport.open()
      return FrameSource { handle in
        for try await frame in frames { await handle(frame) }
      }
    }
    sendFrame = { try await transport.send($0) }
  }

  /// The first device's address: the one it holds or is claiming, or 254 if
  /// it found no free address.
  public var address: UInt8 { engine.address }

  /// The NAME the first device claims its address with. The node changes
  /// the device instance if another device claims the same NAME, and
  /// another device can set the device and system instances with a group
  /// function command; save the NAME so the device keeps them across
  /// restarts.
  public var name: DeviceName { engine.name }

  /// The devices the node hosts, as they are now: their addresses, NAMEs
  /// and heartbeat intervals change as they claim addresses and answer
  /// group functions.
  public var devices: [Device] { engine.devices.map(\.settings) }

  /// The identifiers of the devices the node hosts, in the order of
  /// ``devices``.
  public var deviceIDs: [DeviceID] { engine.devices.indices.map(DeviceID.init(rawValue:)) }

  /// The configuration information the node sends when asked. Another
  /// device can change the installation descriptions with a group function
  /// command; save them so the device keeps them across restarts.
  public var configurationInformation: ConfigurationInformation? {
    engine.configurationInformation
  }

  /// The devices on the bus, if the node was created with
  /// `discoversDevices: true`.
  public var deviceList: DeviceList? { engine.deviceList }

  /// Sets the handler that answers group functions for a PGN, or for every
  /// PGN without a handler of its own, or removes it.
  ///
  /// Handlers come before the node's own answers, including those for the
  /// network management PGNs, so a handler can extend or replace them.
  ///
  /// Replaces upstream's `AddGroupFunctionHandler` and
  /// `RemoveGroupFunctionHandler`.
  ///
  /// - Parameters:
  ///   - handler: The handler, or `nil` to remove it.
  ///   - pgn: The PGN it handles, or `nil` for every PGN.
  public func setGroupFunctionHandler(_ handler: GroupFunctionHandler?, for pgn: UInt32? = nil) {
    engine.groupFunctionHandlers[pgn] = handler
  }

  /// Sets the handler that answers ISO requests the node doesn't answer
  /// itself, or removes it.
  public func setISORequestHandler(_ handler: ISORequestHandler?) {
    engine.isoRequestHandler = handler
  }

  /// Opens the transport and runs the node until the transport's frames end
  /// or the task is cancelled.
  ///
  /// If the transport fails to open, the node tries again every second.
  /// When `run()` returns, every ``messages()`` sequence finishes, and the
  /// node can be run again.
  ///
  /// - Throws: `CancellationError` if the task is cancelled while the
  ///   transport is opening, or an error from the transport's frames.
  public func run() async throws {
    precondition(!isRunning, "Node.run() is already running")
    isRunning = true
    hasStopped = false
    defer { stop() }
    let frames = try await openWithRetries()
    scheduleTimer()
    try await frames.deliver { frame in await self.handle(frame) }
  }

  /// Returns a sequence of the messages the node receives from now on,
  /// including network management messages such as address claims.
  ///
  /// Each call returns a new sequence, and every sequence gets every
  /// message. The sequence finishes when ``run()`` returns. Messages wait in
  /// the sequence until they're read, so keep reading it.
  ///
  /// A message's ``Message/timestamp`` is the time its first frame arrived,
  /// in milliseconds since the node was created.
  ///
  /// - Parameter includingSent: Whether to include the messages the node's
  ///   devices send, as upstream forwards its own messages to its forward
  ///   stream. A gateway logging all traffic wants them.
  public func messages(includingSent: Bool = false) -> AsyncStream<Message> {
    let (stream, continuation) = AsyncStream.makeStream(of: Message.self)
    let id = nextSubscriberID
    nextSubscriberID += 1
    subscribers[id] = (continuation, includingSent)
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeSubscriber(id) }
    }
    return stream
  }

  /// Returns a sequence of the node's events from now on: when it opens,
  /// and when a device's address, NAME, heartbeat or the installation
  /// descriptions change.
  ///
  /// Each call returns a new sequence, which finishes when ``run()``
  /// returns.
  public func events() -> AsyncStream<Event> {
    let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
    let id = nextSubscriberID
    nextSubscriberID += 1
    eventSubscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeSubscriber(id) }
    }
    return stream
  }

  /// Whether the node is open: its transport is open and its devices have
  /// started claiming their addresses.
  public var isOpen: Bool { engine.isOpen }

  /// Whether a device can send now: the node is open, isn't listening only,
  /// and in ``Mode/node`` mode the device has claimed an address.
  public func isReady(_ device: DeviceID = .first) -> Bool {
    engine.devices.indices.contains(device.rawValue) && engine.isReady(device.rawValue)
  }

  /// Waits until a device can send: until the node opens and, in
  /// ``Mode/node`` mode, the device has claimed an address. Call it before
  /// the first ``send(_:from:)``, while ``run()`` runs in another task.
  ///
  /// - Throws: ``NodeError/listenOnly`` for a node that never sends,
  ///   ``NodeError/noAddress`` if the device found no free address,
  ///   ``NodeError/notOpen`` if ``run()`` returns first, or
  ///   `CancellationError`.
  public func waitUntilReady(_ device: DeviceID = .first) async throws {
    try checkDevice(device.rawValue)
    guard mode != .listenOnly else { throw NodeError.listenOnly }
    while !engine.isReady(device.rawValue) {
      if engine.hasNoAddress(device.rawValue) { throw NodeError.noAddress }
      if !isRunning && hasStopped { throw NodeError.notOpen }
      try await waitForEngineOutput()
    }
  }

  /// Waits until the engine's state may have changed, which the node
  /// signals each time it passes on the engine's output.
  private func waitForEngineOutput() async throws {
    let id = nextSubscriberID
    nextSubscriberID += 1
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        if Task.isCancelled {
          continuation.resume(throwing: CancellationError())
        } else {
          stateWaiters[id] = continuation
        }
      }
    } onCancel: {
      Task { await self.resumeStateWaiter(id, throwing: CancellationError()) }
    }
  }

  private func resumeStateWaiter(_ id: Int, throwing error: (any Error)? = nil) {
    guard let continuation = stateWaiters.removeValue(forKey: id) else { return }
    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
  }

  /// Whether a device lists a PGN as one it transmits (`IsTxPGN`).
  public func isTransmitted(_ pgn: UInt32, by device: DeviceID = .first) -> Bool {
    let device = device.rawValue
    return engine.devices.indices.contains(device) && engine.isTransmitted(pgn, by: device)
  }

  /// Sends a message from one of the node's devices.
  ///
  /// The message's source is replaced with the device's address. A message of
  /// up to eight bytes is sent in one frame unless its PGN is a fast-packet
  /// PGN (see ``Message/Framing-swift.enum/singleFrame``); anything longer is sent as a
  /// fast packet.
  ///
  /// A message with ``Message/Framing-swift.enum/transportProtocol`` framing that doesn't fit in
  /// one frame is sent by ISO transport protocol instead, which only a full
  /// node can do, one message at a time. This method returns once the
  /// session is announced; the node sends the data packets afterwards, every
  /// 50 ms for a broadcast or as the receiver asks for them. Messages sent to
  /// one device by transport protocol must be shorter than 223 bytes for
  /// upstream's receivers to accept them.
  ///
  /// - Parameters:
  ///   - message: The message to send.
  ///   - device: The node's device to send from.
  /// - Throws: ``NodeError`` if the device can't send the message now, or an
  ///   error from the transport.
  public func send(_ message: Message, from device: DeviceID = .first) async throws {
    let device = device.rawValue
    let now = clock.now()
    transmit(engine.poll(at: now))
    // A transport protocol send sets a deadline for its next packet.
    defer { scheduleTimer() }
    defer { deliverEngineOutput() }
    let frames = try engine.send(message, from: device, at: now)
    try await enqueue(frames, retriesInformation: false).value
  }

  /// Sends a parameter group from one of the node's devices.
  ///
  /// - Parameters:
  ///   - parameterGroup: The parameter group to send.
  ///   - priority: The priority, or `nil` for the parameter group's default.
  ///   - destination: The destination address. Most parameter groups are
  ///     broadcast.
  ///   - device: The node's device to send from.
  ///   - framing: How to split the message into CAN frames.
  /// - Throws: ``NodeError`` if the node can't send the message now, or an
  ///   error from the transport.
  public func send(
    _ parameterGroup: some ParameterGroup, priority: UInt8? = nil,
    to destination: UInt8 = Message.broadcastAddress, from device: DeviceID = .first,
    framing: Message.Framing = .automatic
  ) async throws {
    var message = parameterGroup.makeMessage(priority: priority, destination: destination)
    message.framing = framing
    try await send(message, from: device)
  }

  // MARK: - Running

  private func openWithRetries() async throws -> FrameSource {
    while true {
      try Task.checkCancellation()
      if let deadline = engine.openRetryTime, deadline > clock.now() {
        try await clock.sleep(deadline)
      }
      do {
        let frames = try await openTransport()
        engine.transportOpened(at: clock.now())
        return frames
      } catch {
        engine.transportFailedToOpen(at: clock.now())
      }
    }
  }

  private func handle(_ frame: CANFrame) {
    let (frames, message, deliveredAfter) = engine.receive(frame, at: clock.now())
    transmit(Array(frames[..<deliveredAfter]))
    if let message {
      for subscriber in subscribers.values { subscriber.continuation.yield(message) }
    }
    transmit(Array(frames[deliveredAfter...]))
    deliverEngineOutput()
    scheduleTimer()
  }

  /// Passes on the engine's events and the messages it sent.
  private func deliverEngineOutput() {
    for event in engine.events {
      for subscriber in eventSubscribers.values { subscriber.yield(event) }
    }
    engine.events = []
    for message in engine.sentMessages {
      for subscriber in subscribers.values where subscriber.includesSent {
        subscriber.continuation.yield(message)
      }
    }
    engine.sentMessages = []
    for id in stateWaiters.keys { resumeStateWaiter(id) }
  }

  private func stop() {
    isRunning = false
    hasStopped = true
    engine.transportClosed()
    timer?.cancel()
    timer = nil
    timerDeadline = nil
    deliverEngineOutput()
    for subscriber in subscribers.values { subscriber.continuation.finish() }
    subscribers = [:]
    for subscriber in eventSubscribers.values { subscriber.finish() }
    eventSubscribers = [:]
    for id in stateWaiters.keys { resumeStateWaiter(id, throwing: NodeError.notOpen) }
  }

  private func removeSubscriber(_ id: Int) {
    subscribers[id] = nil
    eventSubscribers[id] = nil
  }

  /// Makes sure a timer fires at the engine's next deadline.
  private func scheduleTimer() {
    let deadline = engine.nextDeadline
    guard isRunning, deadline != timerDeadline else { return }
    timer?.cancel()
    timerDeadline = deadline
    guard let deadline else {
      timer = nil
      return
    }
    timer = Task { [clock] in
      do { try await clock.sleep(deadline) } catch { return }
      self.timerFired()
    }
  }

  private func timerFired() {
    timerDeadline = nil
    transmit(engine.poll(at: clock.now()))
    deliverEngineOutput()
    scheduleTimer()
  }

  // MARK: - Network management on demand

  /// Runs an engine operation at the current time and sends its frames.
  private func perform(
    _ operation: (inout NodeEngine, UInt64) throws(NodeError) -> [CANFrame]
  ) async throws {
    let now = clock.now()
    transmit(engine.poll(at: now))
    defer {
      deliverEngineOutput()
      scheduleTimer()
    }
    let frames = try operation(&engine, now)
    // Upstream's on-demand sends of product and configuration information
    // try again later too.
    try await enqueue(frames, retriesInformation: true).value
  }

  private func checkDevice(_ device: Int) throws(NodeError) {
    guard engine.devices.indices.contains(device) else {
      throw .noSuchDevice(DeviceID(rawValue: device))
    }
  }

  /// Sends a device's address claim, to every device or to one.
  ///
  /// Ports `SendIsoAddressClaim`.
  public func sendAddressClaim(
    from device: DeviceID = .first, to destination: UInt8 = Message.broadcastAddress
  ) async throws {
    let device = device.rawValue
    try await perform { engine, now throws(NodeError) in
      try engine.sendAddressClaim(from: device, to: destination, at: now)
    }
  }

  /// Sends a device's product information. If the device can't send it now,
  /// it tries again shortly, broadcast.
  ///
  /// Ports `SendProductInformation`.
  public func sendProductInformation(
    from device: DeviceID = .first, to destination: UInt8 = Message.broadcastAddress,
    transportProtocol: Bool = false
  ) async throws {
    let device = device.rawValue
    try checkDevice(device)
    try await perform { engine, now in
      engine.sendProductInformation(
        from: device, to: destination, transportProtocol: transportProtocol, at: now)
    }
  }

  /// Sends the configuration information from a device. If the device
  /// can't send it now, it tries again shortly, broadcast.
  ///
  /// Ports `SendConfigurationInformation`.
  public func sendConfigurationInformation(
    from device: DeviceID = .first, to destination: UInt8 = Message.broadcastAddress,
    transportProtocol: Bool = false
  ) async throws {
    let device = device.rawValue
    try checkDevice(device)
    try await perform { engine, now in
      engine.sendConfigurationInformation(
        from: device, to: destination, transportProtocol: transportProtocol, at: now)
    }
  }

  /// Sends one of a device's PGN lists.
  ///
  /// Ports `SendTxPGNList` and `SendRxPGNList`.
  public func sendPGNList(
    _ kind: PGNList.Kind, from device: DeviceID = .first,
    to destination: UInt8 = Message.broadcastAddress,
    transportProtocol: Bool = false
  ) async throws {
    let device = device.rawValue
    try await perform { engine, now throws(NodeError) in
      try engine.sendPGNList(
        kind, from: device, to: destination, transportProtocol: transportProtocol, at: now)
    }
  }

  /// Sends a heartbeat from a device now, outside its schedule, with no
  /// sequence number.
  ///
  /// Ports `SendHeartbeat`.
  public func sendHeartbeat(from device: DeviceID = .first) async throws {
    let device = device.rawValue
    try await perform { engine, now throws(NodeError) in
      try engine.sendHeartbeat(from: device, at: now)
    }
  }

  /// Claims every device's address again.
  ///
  /// Ports `Restart`.
  public func restartAddressClaim() async throws {
    try await perform { engine, now in engine.restartAddressClaim(at: now) }
  }

  // MARK: - Settings at run time

  /// Changes how often a device sends its heartbeat, or turns it off.
  ///
  /// Ports `SetHeartbeatIntervalAndOffset`.
  ///
  /// - Parameters:
  ///   - interval: The interval, kept between 1 and 655.32 seconds, or `nil`
  ///     to stop sending heartbeats.
  ///   - offset: How long after the node opened the first heartbeat was
  ///     due, which later ones keep in step with, or `nil` to keep the
  ///     current offset (10 seconds by default). Only takes effect once the
  ///     node is open.
  ///   - device: The device, or `nil` for every device.
  public func setHeartbeatInterval(
    _ interval: Duration?, offset: Duration? = nil, for device: DeviceID? = nil
  ) throws {
    if let device { try checkDevice(device.rawValue) }
    let now = clock.now()
    for index in device.map({ [$0.rawValue] }) ?? Array(engine.devices.indices) {
      engine.setHeartbeat(
        of: index, interval: interval.map(NodeClock.milliseconds),
        offset: offset.map(NodeClock.milliseconds), at: now)
    }
    deliverEngineOutput()
    scheduleTimer()
  }

  /// Changes a device's device and system instances, and announces its new
  /// NAME with an address claim.
  ///
  /// Ports `SetDeviceInformationInstances`.
  ///
  /// - Parameters:
  ///   - deviceInstance: The new device instance, or `nil` to keep it.
  ///   - systemInstance: The new system instance (4 bits), or `nil` to keep
  ///     it.
  ///   - device: The node's device.
  public func setInstances(
    deviceInstance: UInt8? = nil, systemInstance: UInt8? = nil, for device: DeviceID = .first
  ) throws {
    let device = device.rawValue
    try checkDevice(device)
    engine.setInstances(
      of: device, lower: deviceInstance.map { $0 & 0x07 }, upper: deviceInstance.map { $0 >> 3 },
      system: systemInstance.map { $0 & 0x0f }, at: clock.now())
    deliverEngineOutput()
    scheduleTimer()
  }

  /// Changes the product information a device sends when asked.
  ///
  /// Ports `SetProductInformation`.
  public func setProductInformation(
    _ information: ProductInformation, for device: DeviceID = .first
  )
    throws
  {
    let device = device.rawValue
    try checkDevice(device)
    engine.devices[device].productInformation = information
  }

  /// Changes the configuration information the node sends when asked, or
  /// refuses requests for it with `nil`.
  ///
  /// Ports `SetConfigurationInformation`.
  public func setConfigurationInformation(_ information: ConfigurationInformation?) {
    engine.configurationInformation = information
  }

  // MARK: - Transmitting

  /// Sends frames the node sends on its own, such as address claims.
  ///
  /// When more than ``maxQueuedFrames`` would be waiting, the frames are
  /// dropped, as upstream drops frames when its send buffer is full. Frames
  /// that are dropped or fail to send are handled as upstream handles a
  /// failed send: product and configuration information go out again later,
  /// and a transport protocol send ends.
  private func transmit(_ frames: [CANFrame]) {
    guard !frames.isEmpty else { return }
    guard queuedFrameCount + frames.count <= Self.maxQueuedFrames else {
      engine.transmissionFailed(frames, retriesInformation: true, at: clock.now())
      return
    }
    enqueue(frames, retriesInformation: true)
  }

  /// Queues frames to send after every frame queued before them, so one
  /// message's frames never interleave with another's.
  ///
  /// - Parameter retriesInformation: Whether product and configuration
  ///   information among the frames are sent again if they fail.
  @discardableResult
  private func enqueue(_ frames: [CANFrame], retriesInformation: Bool) -> Task<Void, any Error> {
    let previous = lastTransmission
    let sendFrame = sendFrame
    queuedFrameCount += frames.count
    let transmission = Task {
      _ = await previous?.result
      var sentCount = 0
      do {
        for frame in frames {
          try await sendFrame(frame)
          sentCount += 1
        }
      } catch {
        transmissionEnded(
          frames, sentCount: sentCount, retriesInformation: retriesInformation)
        throw error
      }
      transmissionEnded(
        frames, sentCount: sentCount, retriesInformation: retriesInformation)
    }
    lastTransmission = transmission
    return transmission
  }

  /// Updates the queue once a transmission ends, and tells the engine about
  /// the frames it couldn't send.
  private func transmissionEnded(
    _ frames: [CANFrame], sentCount: Int, retriesInformation: Bool
  ) {
    queuedFrameCount -= frames.count
    guard sentCount < frames.count, isRunning else { return }
    engine.transmissionFailed(
      Array(frames[sentCount...]), retriesInformation: retriesInformation, at: clock.now())
    scheduleTimer()
  }
}

/// Why a node can't send a message.
public enum NodeError: Error, Sendable, Hashable {
  /// The node isn't running, or is still opening its transport.
  case notOpen
  /// The node is in ``Node/Mode/listenOnly`` mode.
  case listenOnly
  /// The node is claiming its address. Try again once the claim is done,
  /// 250 ms after it started.
  case claimingAddress
  /// Every address was taken, so the node has none.
  case noAddress
  /// A message is already being sent by transport protocol, which sends one
  /// message at a time.
  case transferInProgress
  /// Only a node in ``Node/Mode/node`` mode can send by transport protocol.
  case notAFullNode
  /// The node has no device with this index.
  case noSuchDevice(Node.DeviceID)
  /// The message can't be framed.
  case invalidMessage(FramingError)
}

/// The frames a transport receives, with the sequence's type erased.
private struct FrameSource: Sendable {
  let deliver: @Sendable (_ handle: @Sendable (CANFrame) async -> Void) async throws -> Void
}

/// A clock reduced to what the node needs: milliseconds since the node was
/// created, and sleeping until a given millisecond.
struct NodeClock: Sendable {
  let now: @Sendable () -> UInt64
  let sleep: @Sendable (_ until: UInt64) async throws -> Void

  init<C: Clock>(_ clock: C) where C.Duration == Duration {
    let start = clock.now
    now = { Self.milliseconds(start.duration(to: clock.now)) }
    sleep = { milliseconds in
      try await clock.sleep(until: start.advanced(by: .milliseconds(milliseconds)), tolerance: nil)
    }
  }

  static func milliseconds(_ duration: Duration) -> UInt64 {
    let (seconds, attoseconds) = duration.components
    guard seconds >= 0 else { return 0 }
    return UInt64(seconds) * 1000 + UInt64(attoseconds / 1_000_000_000_000_000)
  }
}
