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
    public init(
      address: UInt8 = 15,
      name: DeviceName = .default,
      productInformation: ProductInformation? = nil,
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

  /// Answers an ISO request for a PGN the node doesn't answer itself.
  ///
  /// The handler gets the requested PGN, the requester's address and the
  /// index of the node's device the request is for, and returns the
  /// messages that device sends in reply, or `nil` if it doesn't handle the
  /// PGN. The device then sends a negative acknowledgement if the request
  /// was addressed to it. A broadcast request asks every device in turn.
  /// The handler runs on the node, so it must be quick.
  ///
  /// Replaces upstream's `SetISORqstHandler` callback.
  public typealias ISORequestHandler =
    @Sendable (_ requestedPGN: UInt32, _ requester: UInt8, _ device: Int) -> [Message]?

  /// How the node takes part in the bus.
  public nonisolated let mode: Mode

  private var engine: NodeEngine
  private let clock: NodeClock
  private let openTransport: @Sendable () async throws -> FrameSource
  private let sendFrame: @Sendable (CANFrame) async throws -> Void
  private var subscribers: [Int: AsyncStream<Message>.Continuation] = [:]
  private var nextSubscriberID = 0
  private var lastTransmission: Task<Void, any Error>?
  private var timer: Task<Void, Never>?
  private var timerDeadline: UInt64?
  private var isRunning = false

  /// Creates a node hosting one device.
  ///
  /// - Parameters:
  ///   - transport: The CAN bus connection.
  ///   - mode: How the node takes part in the bus. Upstream defaults to
  ///     listening only.
  ///   - address: The address to claim first. If another device holds it,
  ///     the node tries the following addresses. Pass 254 to start from 14.
  ///     Save ``address`` when it changes and pass it here next time, so the
  ///     device keeps its address across restarts.
  ///   - name: The NAME to claim the address with. Every device on a bus
  ///     needs a different NAME.
  ///   - productInformation: The product information the node sends when
  ///     asked.
  ///   - configurationInformation: The configuration information the node
  ///     sends when asked, or `nil` to refuse requests for it.
  ///   - catalog: Which PGNs are sent and received as fast packets.
  ///   - transmitPGNs: The PGNs the device sends, beyond the network
  ///     management PGNs every node sends. The node lists them when asked.
  ///   - receivePGNs: The PGNs the device receives, beyond the network
  ///     management PGNs. The node lists them when asked.
  ///   - handlesOnlyKnownMessages: Whether to drop received messages whose
  ///     PGN isn't in the catalog.
  ///   - discoversDevices: Whether to keep a ``DeviceList`` of the devices
  ///     on the bus, asking them for their details as upstream's
  ///     `tN2kDeviceList` does.
  ///   - heartbeatInterval: How often to send a heartbeat, between 1 and
  ///     655.32 seconds, or `nil` for none. The first is sent 10 seconds
  ///     after the node opens.
  ///   - clock: The clock that times the open sequence and address claim.
  public init(
    transport: some CANTransport,
    mode: Mode = .listenOnly,
    address: UInt8 = 15,
    name: DeviceName = .default,
    productInformation: ProductInformation = .default,
    configurationInformation: ConfigurationInformation? = .default,
    catalog: PGNCatalog = PGNCatalog(),
    transmitPGNs: [UInt32] = [],
    receivePGNs: [UInt32] = [],
    handlesOnlyKnownMessages: Bool = false,
    discoversDevices: Bool = false,
    heartbeatInterval: Duration? = .seconds(60),
    clock: some Clock<Duration> = ContinuousClock()
  ) {
    self.init(
      transport: transport, mode: mode,
      devices: [
        Device(
          address: address, name: name, productInformation: productInformation,
          transmitPGNs: transmitPGNs, receivePGNs: receivePGNs,
          heartbeatInterval: heartbeatInterval)
      ],
      configurationInformation: configurationInformation, catalog: catalog,
      handlesOnlyKnownMessages: handlesOnlyKnownMessages, discoversDevices: discoversDevices,
      clock: clock)
  }

  /// Creates a node hosting several devices.
  ///
  /// - Parameters:
  ///   - transport: The CAN bus connection.
  ///   - mode: How the node takes part in the bus. Upstream defaults to
  ///     listening only.
  ///   - devices: The devices the node hosts, at least one.
  ///   - configurationInformation: The configuration information the
  ///     devices send when asked, or `nil` to refuse requests for it.
  ///   - catalog: Which PGNs are sent and received as fast packets.
  ///   - handlesOnlyKnownMessages: Whether to drop received messages whose
  ///     PGN isn't in the catalog.
  ///   - discoversDevices: Whether to keep a ``DeviceList`` of the devices
  ///     on the bus. The first device asks them for their details.
  ///   - clock: The clock that times the open sequence and address claims.
  public init(
    transport: some CANTransport,
    mode: Mode = .listenOnly,
    devices: [Device],
    configurationInformation: ConfigurationInformation? = .default,
    catalog: PGNCatalog = PGNCatalog(),
    handlesOnlyKnownMessages: Bool = false,
    discoversDevices: Bool = false,
    clock: some Clock<Duration> = ContinuousClock()
  ) {
    self.mode = mode
    engine = NodeEngine(
      mode: mode, devices: devices, catalog: catalog,
      handlesOnlyKnownMessages: handlesOnlyKnownMessages,
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

  /// The configuration information the node sends when asked. Another
  /// device can change the installation descriptions with a group function
  /// command; save them so the device keeps them across restarts.
  public var configurationInformation: ConfigurationInformation? {
    engine.configurationInformation
  }

  /// The devices on the bus, if the node was created with
  /// `discoversDevices: true`.
  public var deviceList: DeviceList? { engine.deviceList }

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
  public func messages() -> AsyncStream<Message> {
    let (stream, continuation) = AsyncStream.makeStream(of: Message.self)
    let id = nextSubscriberID
    nextSubscriberID += 1
    subscribers[id] = continuation
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeSubscriber(id) }
    }
    return stream
  }

  /// Sends a message from one of the node's devices.
  ///
  /// The message's source is replaced with the device's address. A message of
  /// up to eight bytes is sent in one frame unless its PGN is a fast-packet
  /// PGN; anything longer is sent as a fast packet.
  ///
  /// A message marked ``Message/isTransportProtocol`` that doesn't fit in
  /// one frame is sent by ISO transport protocol instead, which only a full
  /// node can do, one message at a time. This method returns once the
  /// session is announced; the node sends the data packets afterwards, every
  /// 50 ms for a broadcast or as the receiver asks for them. Messages sent to
  /// one device by transport protocol must be shorter than 223 bytes for
  /// upstream's receivers to accept them.
  ///
  /// - Parameters:
  ///   - message: The message to send.
  ///   - device: The index of the node's device to send from.
  /// - Throws: ``NodeError`` if the device can't send the message now, or an
  ///   error from the transport.
  public func send(_ message: Message, from device: Int = 0) async throws {
    let now = clock.now()
    transmit(engine.poll(at: now))
    // A transport protocol send sets a deadline for its next packet.
    defer { scheduleTimer() }
    let frames = try engine.send(message, from: device, at: now)
    try await enqueue(frames).value
  }

  /// Sends a parameter group from one of the node's devices.
  ///
  /// - Parameters:
  ///   - parameterGroup: The parameter group to send.
  ///   - priority: The priority, or `nil` for the parameter group's default.
  ///   - destination: The destination address. Most parameter groups are
  ///     broadcast.
  /// - Throws: ``NodeError`` if the node can't send the message now, or an
  ///   error from the transport.
  ///   - device: The index of the node's device to send from.
  public func send(
    _ parameterGroup: some ParameterGroup, priority: UInt8? = nil,
    to destination: UInt8 = Message.broadcastAddress, from device: Int = 0
  ) async throws {
    try await send(
      parameterGroup.makeMessage(priority: priority, destination: destination), from: device)
  }

  // MARK: - Running

  private func openWithRetries() async throws -> FrameSource {
    while true {
      try Task.checkCancellation()
      if let deadline = engine.nextDeadline, deadline > clock.now() {
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
      for subscriber in subscribers.values { subscriber.yield(message) }
    }
    transmit(Array(frames[deliveredAfter...]))
    scheduleTimer()
  }

  private func stop() {
    isRunning = false
    engine.transportClosed()
    timer?.cancel()
    timer = nil
    timerDeadline = nil
    for subscriber in subscribers.values { subscriber.finish() }
    subscribers = [:]
  }

  private func removeSubscriber(_ id: Int) {
    subscribers[id] = nil
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
    scheduleTimer()
  }

  // MARK: - Transmitting

  /// Sends frames the node sends on its own, such as address claims.
  /// Transport errors are dropped, as upstream drops them.
  private func transmit(_ frames: [CANFrame]) {
    guard !frames.isEmpty else { return }
    enqueue(frames)
  }

  /// Queues frames to send after every frame queued before them, so one
  /// message's frames never interleave with another's.
  @discardableResult
  private func enqueue(_ frames: [CANFrame]) -> Task<Void, any Error> {
    let previous = lastTransmission
    let sendFrame = sendFrame
    let transmission = Task {
      _ = await previous?.result
      for frame in frames { try await sendFrame(frame) }
    }
    lastTransmission = transmission
    return transmission
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
  case noSuchDevice(Int)
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
