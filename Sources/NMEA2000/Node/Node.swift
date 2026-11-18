// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A device on an NMEA 2000 bus: it opens a CAN transport, claims an address,
/// sends messages and delivers the messages it receives.
///
/// Create a node from a transport and a ``Configuration``, run it with
/// ``run()``, and read what it receives with ``messages(of:includingSent:bufferingPolicy:)``
/// or ``messages(includingSent:bufferingPolicy:)``:
///
/// ```swift
/// let node = Node(
///   transport: transport,
///   configuration: .node(myDevice, configurationInformation: myConfigurationInformation))
/// try await withThrowingTaskGroup(of: Void.self) { group in
///   group.addTask { try await node.run() }
///   group.addTask {
///     for await position in await node.messages(of: PositionRapidUpdate.self) {
///       print(position.latitude ?? .nan, position.longitude ?? .nan)
///     }
///   }
///   group.addTask {
///     try await node.waitUntilReady()
///     try await node.send(WindData(reference: .apparent, windSpeed: 5, windAngle: 1))
///   }
///   try await group.waitForAll()
/// }
/// ```
///
/// When the transport opens, the node waits 200 ms and then claims its
/// address. While the claim is in progress (250 ms, longer if another device
/// contests the address) sending throws ``NodeError/claimingAddress``;
/// ``waitUntilReady(_:)`` waits for it to end.
///
/// Ports `tNMEA2000` for one device: the open sequence, sending, receiving
/// and address claiming. Upstream calls message handlers from
/// `ParseMessages`, which the application calls in its main loop; here
/// ``run()`` handles frames as they arrive and ``messages(includingSent:bufferingPolicy:)`` delivers them.
public actor Node {
  /// How the node takes part in the bus.
  public nonisolated let mode: Mode

  /// The most frames the node queues to send before it drops the frames it
  /// sends on its own, as upstream's send frame buffer holds 40 by default
  /// (`SetN2kCANSendFrameBufSize`). Messages sent with ``send(_:from:)``
  /// wait for the transport instead.
  private static let maxQueuedFrames = 40

  private var engine: NodeEngine
  private let clock: NodeClock
  private let openTransport: @Sendable () async throws -> FrameSource
  private let sendFrame: @Sendable (CANFrame) async throws -> Void
  private let closeTransport: @Sendable () async -> Void
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
  /// Whether ``run()`` has stopped since it last started.
  private var hasStopped = false
  /// Whether ``run()`` has stopped and is ending its transmissions and
  /// closing the transport.
  private var isClosing = false
  /// The transmissions queued or in progress, so they can be cancelled.
  private var transmissions: [Int: Task<Void, any Error>] = [:]

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
      configurationInformation: configurationInformation, discoversDevices: discoversDevices)
    self.clock = NodeClock(clock)
    openTransport = {
      let frames = try await transport.open()
      return FrameSource { handle in
        for try await frame in frames { await handle(frame) }
      }
    }
    sendFrame = { try await transport.send($0) }
    closeTransport = { await transport.close() }
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
  /// or the task is cancelled, then closes the transport.
  ///
  /// Run it in a task whose errors are handled, alongside the code that
  /// uses the node:
  ///
  /// ```swift
  /// try await withThrowingTaskGroup(of: Void.self) { group in
  ///   group.addTask { try await node.run() }
  ///   group.addTask {
  ///     try await node.waitUntilReady()
  ///     try await node.send(PositionRapidUpdate(latitude: 60.17, longitude: 24.94))
  ///   }
  ///   try await group.next()
  ///   group.cancelAll()
  /// }
  /// ```
  ///
  /// If the transport fails to open, the node tries again every second.
  /// When `run()` returns, every message sequence finishes, and the
  /// node can be run again.
  ///
  /// Messages still waiting to be sent when the node stops aren't sent:
  /// their ``send(_:from:)`` calls throw ``NodeError/notOpen``. The node
  /// cancels a frame the transport is in the middle of sending and waits
  /// for it, so nothing is sent once the transport is closed.
  ///
  /// - Throws: ``NodeError/alreadyRunning`` if the node is already running
  ///   or still closing its transport, `CancellationError` if the task is
  ///   cancelled while the transport is opening, or an error from the
  ///   transport's frames.
  public func run() async throws {
    guard !isRunning, !isClosing else { throw NodeError.alreadyRunning }
    isRunning = true
    hasStopped = false
    let frames: FrameSource
    do {
      frames = try await openWithRetries()
    } catch {
      stop()
      throw error
    }
    scheduleTimer()
    var failure: (any Error)?
    do {
      try await frames.deliver { frame in await self.handle(frame) }
    } catch {
      failure = error
    }
    stop()
    isClosing = true
    defer { isClosing = false }
    await cancelTransmissions()
    await closeTransport()
    if let failure { throw failure }
  }

  /// Returns a sequence of the messages the node receives from now on,
  /// including network management messages such as address claims.
  ///
  /// Each call returns a new sequence, and every sequence gets every
  /// message. The sequence finishes when ``run()`` returns. Messages wait in
  /// the sequence until they're read, up to the buffering policy's limit.
  ///
  /// A message's ``Message/timestamp`` is the time its first frame arrived,
  /// since the node was created.
  ///
  /// The sequence finishes cleanly whether ``run()`` returns or throws;
  /// ``run()`` itself throws any transport error, so run it where its error
  /// is handled (see ``run()``).
  ///
  /// - Parameters:
  ///   - includingSent: Whether to include the messages the node's devices
  ///     send, as upstream forwards its own messages to its forward stream.
  ///     A gateway logging all traffic wants them.
  ///   - bufferingPolicy: How many messages wait to be read before older or
  ///     newer ones are dropped. The default keeps the newest 1024, so a
  ///     slow reader on a busy bus loses the oldest rather than using ever
  ///     more memory; pass `.unbounded` to keep them all.
  public func messages(
    includingSent: Bool = false,
    bufferingPolicy: AsyncStream<Message>.Continuation.BufferingPolicy = .bufferingNewest(1024)
  ) -> AsyncStream<Message> {
    let (stream, continuation) = AsyncStream.makeStream(
      of: Message.self, bufferingPolicy: bufferingPolicy)
    let id = nextSubscriberID
    nextSubscriberID += 1
    subscribers[id] = (continuation, includingSent)
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeSubscriber(id) }
    }
    return stream
  }

  /// Returns a sequence of the parameter groups of one type the node
  /// receives from now on, decoded. Messages that don't decode are skipped.
  ///
  /// ```swift
  /// for await wind in await node.messages(of: WindData.self) {
  ///   print(wind.windSpeed ?? .nan)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - type: The parameter group type.
  ///   - includingSent: Whether to include those the node's devices send.
  ///   - bufferingPolicy: How many messages wait to be read before older or
  ///     newer ones are dropped.
  public func messages<Group: ParameterGroup>(
    of type: Group.Type, includingSent: Bool = false,
    bufferingPolicy: AsyncStream<Message>.Continuation.BufferingPolicy = .bufferingNewest(1024)
  ) -> some AsyncSequence<Group, Never> & Sendable {
    messages(includingSent: includingSent, bufferingPolicy: bufferingPolicy).compactMap {
      @Sendable message in message.pgn == Group.pgn ? try? Group(message) : nil
    }
  }

  /// Returns a sequence of the node's events from now on: when it opens,
  /// and when a device's address, NAME, heartbeat or the installation
  /// descriptions change.
  ///
  /// Each call returns a new sequence, which finishes when ``run()``
  /// returns. Events wait in the sequence until they're read, up to the
  /// buffering policy's limit.
  ///
  /// - Parameter bufferingPolicy: How many events wait to be read before
  ///   older or newer ones are dropped. The default keeps the newest 1024;
  ///   pass `.unbounded` to keep them all.
  public func events(
    bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .bufferingNewest(1024)
  ) -> AsyncStream<Event> {
    let (stream, continuation) = AsyncStream.makeStream(
      of: Event.self, bufferingPolicy: bufferingPolicy)
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
  /// The message's frames are queued in order with every other message's.
  /// Cancelling the calling task doesn't take them back: a message is sent
  /// whole once it's queued, unless the node stops first.
  ///
  /// - Parameters:
  ///   - message: The message to send.
  ///   - device: The node's device to send from.
  /// - Throws: ``NodeError`` if the device can't send the message now or the
  ///   node stops before the message is sent, or an error from the
  ///   transport.
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
    let (events, sentMessages) = engine.takeOutput()
    for event in events {
      for subscriber in eventSubscribers.values { subscriber.yield(event) }
    }
    for message in sentMessages {
      for subscriber in subscribers.values where subscriber.includesSent {
        subscriber.continuation.yield(message)
      }
    }
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
        of: index, interval: interval.map(\.wholeMilliseconds),
        offset: offset.map(\.wholeMilliseconds), at: now)
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
  ) throws {
    let device = device.rawValue
    try checkDevice(device)
    engine.setProductInformation(information, of: device)
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
    let id = nextSubscriberID
    nextSubscriberID += 1
    queuedFrameCount += frames.count
    let transmission = Task {
      _ = await previous?.result
      defer { transmissions[id] = nil }
      var sentCount = 0
      do {
        for frame in frames {
          // Nothing is sent once the node has stopped.
          guard isRunning else { throw NodeError.notOpen }
          try await sendFrame(frame)
          sentCount += 1
        }
      } catch {
        transmissionEnded(
          frames, sentCount: sentCount, retriesInformation: retriesInformation)
        // A frame cancelled because the node stopped fails like the frames
        // queued behind it.
        throw isRunning ? error : NodeError.notOpen
      }
      transmissionEnded(
        frames, sentCount: sentCount, retriesInformation: retriesInformation)
    }
    transmissions[id] = transmission
    lastTransmission = transmission
    return transmission
  }

  /// Ends every transmission once the node has stopped: cancels the frame
  /// being sent, and waits for it and for those queued behind it, which
  /// fail without sending.
  private func cancelTransmissions() async {
    while let last = lastTransmission {
      for transmission in transmissions.values { transmission.cancel() }
      _ = await last.result
      if lastTransmission == last { lastTransmission = nil }
    }
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

/// The frames a transport receives, with the sequence's type erased.
private struct FrameSource: Sendable {
  let deliver: @Sendable (_ handle: @Sendable (CANFrame) async -> Void) async throws -> Void
}
