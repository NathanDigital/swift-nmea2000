// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The node's state machine, with no I/O: ``Node`` feeds it the time, the
/// result of opening the transport and received frames, and sends the frames
/// it returns.
///
/// A node hosts one or more devices. Each has its own address, NAME,
/// address claim, transport protocol session and heartbeat; they share the
/// transport, the reassembly buffers and the configuration information.
///
/// Time is milliseconds since the node started. Like upstream on Arduino,
/// whose scheduler uses the 32-bit `millis()`, a deadline is reached at its
/// exact millisecond. The heartbeat is the exception: upstream schedules it
/// with a 64-bit timer that fires only once its deadline has passed.
///
/// Ports the open sequence, `SendMsg` checks, `ParseMessages`, address
/// claiming, the ISO transport protocol, ISO requests and the heartbeat of
/// `tNMEA2000`.
struct NodeEngine: Sendable {
  /// How long to wait after the transport opens before claiming an address.
  /// Upstream found some CAN controllers misbehave when sending straight
  /// away.
  static let openDelay: UInt64 = 200

  /// How long to wait before trying again when the transport fails to open.
  static let openRetryDelay: UInt64 = 1000

  /// How long an address claim must go unchallenged before the device uses
  /// the address (`N2kAddressClaimTimeout`).
  static let addressClaimTimeout: UInt64 = 250

  /// The address that means the device has none (`N2kNullCanBusAddress`).
  static let nullAddress: UInt8 = 254

  /// Where a device without an address starts claiming.
  static let firstClaimedAddress: UInt8 = 14

  /// Commanded address, which tells the device with a NAME to move to a new
  /// address.
  static let commandedAddressPGN: UInt32 = 65240

  /// How long after opening the first heartbeat is due.
  static let heartbeatOffset: UInt64 = 10000

  /// The PGNs every node receives (`DefReceiveMessages`).
  static let defaultReceivePGNs: [UInt32] = [59392, 59904, 60160, 60416, 60928, 65240, 126208]

  /// The most PGNs a PGN list holds (`MAX_PGNS_IN_LIST`).
  static let maxPGNsInList = 74

  /// PGNs whose broadcast ISO requests go unanswered
  /// (`IgnoreBroadcastISORequest`).
  static let ignoredBroadcastRequests: Set<UInt32> = [
    127500, 130060, 130061, 130330, 130561, 130562, 130563, 130564, 130565, 130566,
  ]

  enum OpenState: Hashable {
    /// The transport isn't open; try to open it at the given time.
    case closed(retryAt: UInt64)
    /// The transport is open; claim addresses at the given time.
    case waiting(until: UInt64)
    /// The node is running.
    case open
  }

  /// One device's state (upstream's `tInternalDevice`).
  struct DeviceState: Sendable {
    var address: UInt8
    var name: DeviceName
    /// `nil` to send the first device's.
    var productInformation: ProductInformation?
    var transmitPGNs: [UInt32]
    var receivePGNs: [UInt32]
    /// The heartbeat interval in milliseconds, or `nil` for none.
    var heartbeatInterval: UInt64?
    /// The device's fast-packet sequence counters.
    var framer: MessageFramer

    /// The last address to try before giving up, one before the address the
    /// device last held (upstream's `AddressClaimEndSource`).
    var lastAddressToTry: UInt8 = 0
    /// When the address claim in progress ends, or `nil` if there isn't one.
    var claimDeadline: UInt64?
    /// The message being sent by transport protocol, if any (upstream's
    /// `PendingTPMsg`).
    var transfer: Transfer?
    /// When heartbeats are due, once the node is open (upstream's
    /// `HeartbeatScheduler`).
    var heartbeat: HeartbeatSchedule?
    /// When to send an address claim that was put off for a moment, if any
    /// (upstream's `PendingIsoAddressClaim`).
    var pendingClaim: UInt64?
    /// When to try again to send product information that couldn't be sent
    /// (upstream's `PendingProductInformation`).
    var pendingProductInformation: UInt64?
    /// When to try again to send configuration information that couldn't be
    /// sent (upstream's `PendingConfigurationInformation`).
    var pendingConfigurationInformation: UInt64?

    init(_ device: Node.Device, catalog: PGNCatalog) {
      address = device.address
      name = device.name
      productInformation = device.productInformation
      transmitPGNs = device.transmitPGNs
      receivePGNs = device.receivePGNs
      heartbeatInterval = device.heartbeatInterval.map {
        // Upstream keeps the interval between 1 and 655.32 seconds.
        min(max(NodeClock.milliseconds($0), 1000), 655_320)
      }
      framer = MessageFramer(catalog: catalog, transmitPGNs: device.transmitPGNs)
      resetLastAddressToTry()
    }

    /// Ports `UpdateAddressClaimEndSource`.
    mutating func resetLastAddressToTry() {
      lastAddressToTry = address > 0 ? address - 1 : MessageFramer.maxBusAddress
    }

    /// The device's settings as they are now.
    var settings: Node.Device {
      Node.Device(
        address: address, name: name, productInformation: productInformation,
        transmitPGNs: transmitPGNs, receivePGNs: receivePGNs,
        heartbeatInterval: heartbeatInterval.map { .milliseconds($0) })
    }
  }

  /// A heartbeat schedule synchronised to the time the node opened
  /// (upstream's `tN2kSyncScheduler`).
  struct HeartbeatSchedule: Sendable {
    /// When the node opened.
    var sync: UInt64
    /// How long after opening the first heartbeat is due.
    var offset: UInt64
    var period: UInt64
    /// Heartbeats are sent once this time has passed.
    var next: UInt64 = 0
    var sequence: UInt8 = 0

    init(sync: UInt64, offset: UInt64, period: UInt64, now: UInt64) {
      self.sync = sync
      self.offset = offset
      self.period = period
      scheduleNext(at: now)
    }

    /// Schedules the next heartbeat: the first one if it's still to come,
    /// otherwise the next whole period after it.
    ///
    /// Ports `tN2kSyncScheduler::UpdateNextTime`.
    mutating func scheduleNext(at now: UInt64) {
      let start = sync + offset
      next = start > now ? start : start + ((now - start) / period + 1) * period
    }
  }

  struct Transfer: Sendable {
    var message: Message
    /// How many data packets have been sent (`NextDTSequence`).
    var sentPackets = 0
    /// When to send the next broadcast packet, or give up waiting for a
    /// clear to send (`NextDTSendTime`).
    var deadline: UInt64

    var isBroadcast: Bool { message.destination == Message.broadcastAddress }
    var isComplete: Bool { sentPackets * 7 >= message.data.count }
  }

  let mode: Node.Mode
  private(set) var openState = OpenState.closed(retryAt: 0)
  /// The devices the node hosts, at least one. Group function handlers
  /// (NodeEngine+GroupFunctions.swift) change them.
  var devices: [DeviceState]
  private var assembler: MessageAssembler

  /// The configuration information the node sends when asked, shared by its
  /// devices; `nil` makes it answer requests for it with a negative
  /// acknowledgement.
  var configurationInformation: ConfigurationInformation?

  /// Answers ISO requests the node doesn't answer itself.
  var isoRequestHandler: Node.ISORequestHandler?

  /// The application's group function handlers, by PGN; the one for `nil`
  /// is tried for every PGN.
  var groupFunctionHandlers: [UInt32?: Node.GroupFunctionHandler] = [:]

  /// The devices on the bus, if the node keeps track of them.
  var deviceList: DeviceList?

  /// Events since ``Node`` last took them, for ``Node/events()``.
  var events: [Node.Event] = []

  /// Messages the node has sent since ``Node`` last took them, for
  /// ``Node/messages(includingSent:)``.
  var sentMessages: [Message] = []

  /// When the node opened, which heartbeat schedules are synchronised to
  /// (upstream's `tN2kSyncScheduler::SyncOffset`).
  private var openTime: UInt64?

  init(
    mode: Node.Mode, devices: [Node.Device], catalog: PGNCatalog = PGNCatalog(),
    handlesOnlyKnownMessages: Bool = false, bufferCount: Int = 5,
    configurationInformation: ConfigurationInformation? = .default
  ) {
    precondition(!devices.isEmpty, "A node hosts at least one device")
    self.mode = mode
    self.devices = devices.map { DeviceState($0, catalog: catalog) }
    assembler = MessageAssembler(
      catalog: catalog, bufferCount: bufferCount,
      handlesOnlyKnownMessages: handlesOnlyKnownMessages)
    self.configurationInformation = configurationInformation
  }

  /// Whether the node is open: its transport is open and its devices have
  /// started claiming their addresses.
  var isOpen: Bool { openState == .open }

  /// The first device's address.
  var address: UInt8 { devices[0].address }

  /// The first device's NAME.
  var name: DeviceName { devices[0].name }

  /// The device at an address, as upstream's `FindSourceDeviceIndex` finds
  /// it: addresses 254 and 255 belong to no device.
  func device(at address: UInt8) -> Int? {
    guard address < Self.nullAddress else { return nil }
    return devices.firstIndex { $0.address == address }
  }

  /// The devices a message is for: all of them when it's broadcast, the one
  /// at its destination otherwise.
  func recipients(of message: Message) -> [Int] {
    message.destination == Message.broadcastAddress
      ? Array(devices.indices) : device(at: message.destination).map { [$0] } ?? []
  }

  /// The product information a device sends: its own, or the first
  /// device's.
  func productInformation(of device: Int) -> ProductInformation {
    devices[device].productInformation ?? devices[0].productInformation ?? .default
  }

  // MARK: - Opening

  /// Whether it's time to try opening the transport.
  func shouldOpenTransport(at now: UInt64) -> Bool {
    guard case .closed(let retryAt) = openState else { return false }
    return now >= retryAt
  }

  /// Records that the transport opened.
  mutating func transportOpened(at now: UInt64) {
    openState = .waiting(until: now + Self.openDelay)
  }

  /// Records that the transport failed to open.
  mutating func transportFailedToOpen(at now: UInt64) {
    openState = .closed(retryAt: now + Self.openRetryDelay)
  }

  /// Records that the transport closed. The node opens it again straight
  /// away the next time it runs, and claims its addresses again.
  mutating func transportClosed() {
    openState = .closed(retryAt: 0)
    openTime = nil
    for index in devices.indices {
      devices[index].claimDeadline = nil
      devices[index].transfer = nil
      devices[index].heartbeat = nil
      devices[index].pendingClaim = nil
      devices[index].pendingProductInformation = nil
      devices[index].pendingConfigurationInformation = nil
    }
  }

  /// When to try opening the transport, if it's closed.
  var openRetryTime: UInt64? {
    guard case .closed(let retryAt) = openState else { return nil }
    return retryAt
  }

  /// The next time ``poll(at:)`` has something to do, if any.
  ///
  /// It's `nil` while the transport is closed, since polling does nothing
  /// then: open the transport at ``openRetryTime`` instead.
  var nextDeadline: UInt64? {
    switch openState {
    case .closed: nil
    case .waiting(let until): until
    case .open:
      devices.flatMap {
        [
          $0.claimDeadline, $0.transfer?.deadline, $0.pendingClaim,
          $0.pendingProductInformation, $0.pendingConfigurationInformation,
          heartbeatDeadline(of: $0),
        ]
      }.compactMap { $0 }.min()
    }
  }

  /// When a device's next heartbeat is sent, if the node sends heartbeats
  /// now. Only a full node sends them, and not while the device claims its
  /// address: the claim's own deadline comes first.
  private func heartbeatDeadline(of device: DeviceState) -> UInt64? {
    guard mode == .node, device.claimDeadline == nil else { return nil }
    return device.heartbeat.map { $0.next + 1 }
  }

  /// Advances timers, and returns any frames to send.
  ///
  /// Call it before ``send(_:from:at:)``, and at ``nextDeadline``.
  /// ``receive(_:at:)`` polls itself.
  mutating func poll(at now: UInt64) -> [CANFrame] {
    beforeReceiving(at: now) + afterReceiving(at: now)
  }

  /// What upstream's `ParseMessages` does before reading frames: open, and
  /// send each device's pending messages.
  private mutating func beforeReceiving(at now: UInt64) -> [CANFrame] {
    switch openState {
    case .closed: return []
    case .waiting(let until):
      guard now >= until else { return [] }
      openState = .open
      openTime = now
      var frames: [CANFrame] = []
      for index in devices.indices {
        // A device without an address starts again from the first one.
        if devices[index].address == Self.nullAddress {
          moveToNextAddress(index, restartingFromFirstAddress: true)
        }
        frames += startAddressClaim(index, at: now)
      }
      for index in devices.indices {
        if let period = devices[index].heartbeatInterval {
          devices[index].heartbeat = HeartbeatSchedule(
            sync: now, offset: Self.heartbeatOffset, period: period, now: now)
        }
      }
      events.append(.opened)
      return frames
    case .open:
      var frames: [CANFrame] = []
      for index in devices.indices {
        _ = isClaimingAddress(index, at: now)
        frames += continueTransfer(index, at: now)
        if let time = devices[index].pendingClaim, now >= time {
          devices[index].pendingClaim = nil
          frames += addressClaimFrames(index)
        }
        if let time = devices[index].pendingProductInformation, now >= time {
          frames += sendProductInformation(from: index, to: Message.broadcastAddress, at: now)
        }
        if let time = devices[index].pendingConfigurationInformation, now >= time {
          frames += sendConfigurationInformation(from: index, to: Message.broadcastAddress, at: now)
        }
      }
      return frames
    }
  }

  /// What upstream's `ParseMessages` does after reading frames: send each
  /// device's heartbeat when it's due.
  ///
  /// Ports `SendHeartbeat`.
  private mutating func afterReceiving(at now: UInt64) -> [CANFrame] {
    guard mode == .node else { return [] }
    var frames: [CANFrame] = []
    for index in devices.indices {
      guard var schedule = devices[index].heartbeat, now > schedule.next,
        !isClaimingAddress(index, at: now)
      else { continue }
      schedule.scheduleNext(at: now)
      let message = Heartbeat(
        interval: Double(schedule.period) / 1000, sequenceCounter: schedule.sequence
      ).makeMessage()
      schedule.sequence = schedule.sequence >= 252 ? 0 : schedule.sequence + 1
      devices[index].heartbeat = schedule
      frames += sendSystemMessage(message, from: index, at: now) ?? []
    }
    return frames
  }

  // MARK: - Receiving

  /// Handles a received frame.
  ///
  /// Frames received before the node opens are discarded, as upstream reads
  /// out what the CAN controller collected while starting.
  ///
  /// - Returns: The frames to send, the message the frame completes, if
  ///   any, and how many of the frames come before the application gets
  ///   the message. Upstream answers system messages first, then calls the
  ///   application's handler, then its other handlers such as the device
  ///   list.
  mutating func receive(_ frame: CANFrame, at now: UInt64) -> (
    frames: [CANFrame], message: Message?, deliveredAfter: Int
  ) {
    var frames = beforeReceiving(at: now)
    guard openState == .open else { return (frames, nil, frames.count) }
    let (replies, message) = handle(frame, at: now)
    frames += replies
    let deliveredAfter = frames.count
    if let message, var list = deviceList {
      list.handle(message, at: UInt32(truncatingIfNeeded: now)) { request in
        guard let sent = try? send(request, at: now) else { return false }
        frames += sent
        return true
      }
      deviceList = list
    }
    frames += afterReceiving(at: now)
    return (frames, message, deliveredAfter)
  }

  private mutating func handle(_ frame: CANFrame, at now: UInt64) -> (
    frames: [CANFrame], message: Message?
  ) {
    // Transport protocol sessions with any of the node's devices are its
    // own. Upstream also counts 252 and 253 as local, but a device there
    // can't send replies, so they make no difference.
    let destination = CANIdentifier(frameID: frame.id).destination
    let local = device(at: destination).flatMap {
      devices[$0].address <= MessageFramer.maxBusAddress ? $0 : nil
    }
    let reception = assembler.receive(
      frame, at: UInt32(truncatingIfNeeded: now), localAddress: local.map { devices[$0].address })
    var frames: [CANFrame] = []
    if let local {
      frames += reception.replies.flatMap { sendSystemMessage($0, from: local, at: now) ?? [] }
      if let control = reception.control {
        frames += handleTransportControl(control, for: local, at: now)
      }
    }
    guard let assembled = reception.assembled else { return (frames, nil) }
    if assembled.isSystemMessage && mode == .node {
      let message = assembled.message
      switch message.pgn {
      case ISOAddressClaim.pgn: frames += handleAddressClaim(message, at: now)
      case ISORequest.pgn: frames += handleISORequest(message, at: now)
      case Self.commandedAddressPGN: frames += handleCommandedAddress(message, at: now)
      case GroupFunction.pgn: frames += handleGroupFunction(message, at: now)
      default: break
      }
    }
    return (frames, assembled.message)
  }

  // MARK: - Sending

  /// Returns the frames that carry a message from one of the node's
  /// devices.
  ///
  /// The message's source is replaced with the device's address. A message
  /// marked ``Message/isTransportProtocol`` that doesn't fit a single frame
  /// starts a transport protocol session, which sends its data packets
  /// later; the frames returned announce it.
  ///
  /// - Throws: ``NodeError`` if the device can't send the message now.
  mutating func send(_ message: Message, from device: Int = 0, at now: UInt64) throws(NodeError)
    -> [CANFrame]
  {
    guard openState == .open else { throw .notOpen }
    guard devices.indices.contains(device) else { throw .noSuchDevice(device) }
    guard mode != .listenOnly else { throw .listenOnly }
    var message = message
    message.source = devices[device].address
    let isClaim = message.pgn == ISOAddressClaim.pgn
    guard message.source <= MessageFramer.maxBusAddress || isClaim else { throw .noAddress }
    guard isClaim || !isClaimingAddress(device, at: now) else { throw .claimingAddress }
    do {
      try MessageFramer.validate(message)
    } catch {
      throw .invalidMessage(error)
    }
    if message.isTransportProtocol
      && !MessageFramer.fitsSingleFrame(message, catalog: devices[device].framer.catalog)
    {
      let frames = try startTransfer(message, from: device, at: now)
      sentMessages.append(message)
      return frames
    }
    do {
      let frames = try devices[device].framer.frames(for: message)
      sentMessages.append(message)
      return frames
    } catch {
      throw .invalidMessage(error)
    }
  }

  /// Sends a message a device sends on its own behalf, only as a full node,
  /// and returns `nil` if it can't be sent now.
  private mutating func sendSystemMessage(_ message: Message, from device: Int, at now: UInt64)
    -> [CANFrame]?
  {
    guard mode == .node else { return nil }
    return try? send(message, from: device, at: now)
  }

  /// Sends messages from a device, dropping any that can't be sent.
  mutating func sendAll(_ messages: [Message], from device: Int, at now: UInt64) -> [CANFrame] {
    messages.flatMap { (try? send($0, from: device, at: now)) ?? [] }
  }

  // MARK: - ISO requests

  /// Answers an ISO request from each device it is for, unless the device
  /// is claiming its address.
  ///
  /// Ports `HandleISORequest`.
  private mutating func handleISORequest(_ message: Message, at now: UInt64) -> [CANFrame] {
    // Upstream ignores a request it can't parse, which asks for PGN 0.
    let requested = (try? ISORequest(message))?.requestedPGN ?? 0
    let isAddressed = message.destination != Message.broadcastAddress
    return recipients(of: message).flatMap {
      respond(
        toRequestFor: requested, from: message.source, addressed: isAddressed, by: $0, at: now)
    }
  }

  /// Ports `RespondISORequest`.
  private mutating func respond(
    toRequestFor requested: UInt32, from requester: UInt8, addressed isAddressed: Bool,
    by device: Int, at now: UInt64
  ) -> [CANFrame] {
    guard !isClaimingAddress(device, at: now) else { return [] }
    switch requested {
    case ISOAddressClaim.pgn:
      return addressClaimFrames(device)
    case PGNList.pgn:
      return sendAll(
        [transmitList(of: device, to: requester), receiveList(of: device, to: requester)],
        from: device, at: now)
    case ProductInformation.pgn:
      return sendProductInformation(from: device, to: Message.broadcastAddress, at: now)
    case ConfigurationInformation.pgn:
      return sendConfigurationInformation(from: device, to: Message.broadcastAddress, at: now)
    default:
      if let handler = isoRequestHandler {
        if !isAddressed && Self.ignoredBroadcastRequests.contains(requested) { return [] }
        if let replies = handler(requested, requester, device) {
          return sendAll(replies, from: device, at: now)
        }
      }
      guard isAddressed else { return [] }
      return sendAll(
        [ISOAcknowledgement(control: 1, pgn: requested).makeMessage(destination: requester)],
        from: device, at: now)
    }
  }

  /// Sends a device's product information, or tries again later if it
  /// can't be sent now, broadcast and without transport protocol: 187 ms
  /// plus 8 ms for each unit of the device's address, so devices don't all
  /// retry at once.
  ///
  /// Ports `SendProductInformation` and `SetPendingProductInformation`.
  mutating func sendProductInformation(
    from device: Int, to destination: UInt8, transportProtocol: Bool = false, at now: UInt64
  ) -> [CANFrame] {
    var message = productInformation(of: device).makeMessage(destination: destination)
    message.isTransportProtocol = transportProtocol
    if let frames = try? send(message, from: device, at: now) {
      devices[device].pendingProductInformation = nil
      return frames
    }
    devices[device].pendingProductInformation = now + 187 + UInt64(devices[device].address) * 8
    return []
  }

  /// Sends the configuration information, or tries again later if it can't
  /// be sent now: 187 ms plus 10 ms for each unit of the device's address.
  ///
  /// Ports `SendConfigurationInformation` and
  /// `SetPendingConfigurationInformation`.
  mutating func sendConfigurationInformation(
    from device: Int, to destination: UInt8, transportProtocol: Bool = false, at now: UInt64
  ) -> [CANFrame] {
    var message = configurationReply(to: destination)
    message.isTransportProtocol = transportProtocol
    if let frames = try? send(message, from: device, at: now) {
      devices[device].pendingConfigurationInformation = nil
      return frames
    }
    devices[device].pendingConfigurationInformation =
      now + 187 + UInt64(devices[device].address) * 10
    return []
  }

  // MARK: - Transport protocol

  /// Starts sending a message by transport protocol: a BAM followed by a
  /// data packet every 50 ms, or a request to send that the receiver must
  /// answer within 50 ms.
  ///
  /// Ports `StartSendTPMessage`.
  private mutating func startTransfer(_ message: Message, from device: Int, at now: UInt64)
    throws(NodeError) -> [CANFrame]
  {
    guard devices[device].transfer == nil else { throw .transferInProgress }
    guard mode == .node else { throw .notAFullNode }
    var message = message
    // A PDU2 PGN can only be broadcast (`CheckDestination`).
    if message.pgn & 0xff != 0 { message.destination = Message.broadcastAddress }
    devices[device].transfer = Transfer(
      message: message, deadline: now + TransportProtocol.packetInterval)
    return sendSystemMessage(TransportProtocol.start(message), from: device, at: now) ?? []
  }

  /// Sends the next broadcast packet when it's due, or gives up on a
  /// receiver that stopped answering.
  ///
  /// Ports `SendPendingTPMessage`.
  private mutating func continueTransfer(_ device: Int, at now: UInt64) -> [CANFrame] {
    guard var transfer = devices[device].transfer, now >= transfer.deadline else { return [] }
    guard transfer.isBroadcast else {
      devices[device].transfer = nil
      return []
    }
    let frames = sendDataPacket(&transfer, from: device, at: now) ?? []
    transfer.deadline = now + TransportProtocol.packetInterval
    devices[device].transfer = transfer.isComplete ? nil : transfer
    return frames
  }

  /// Handles a clear to send, acknowledgement or abort from the receiver.
  ///
  /// Ports the sending side of `TestHandleTPMessage`.
  private mutating func handleTransportControl(
    _ control: MessageAssembler.TransportControl, for device: Int, at now: UInt64
  ) -> [CANFrame] {
    guard var transfer = devices[device].transfer, !transfer.isBroadcast else { return [] }
    guard control.pgn == transfer.message.pgn, control.control == .clearToSend else {
      devices[device].transfer = nil
      return []
    }
    var frames: [CANFrame] = []
    // A clear to send for no packets asks the sender to wait.
    if control.packets > 0 {
      guard Int(control.nextPacket) - 1 == transfer.sentPackets else {
        devices[device].transfer = nil
        return []
      }
      for _ in 0..<control.packets where !transfer.isComplete {
        guard let packet = sendDataPacket(&transfer, from: device, at: now) else {
          devices[device].transfer = nil
          return frames
        }
        frames += packet
      }
    }
    transfer.deadline = now + TransportProtocol.clearToSendTimeout
    devices[device].transfer = transfer
    return frames
  }

  /// Sends the next data packet, returning `nil` if it can't be sent.
  ///
  /// Ports `SendTPDT`.
  private mutating func sendDataPacket(_ transfer: inout Transfer, from device: Int, at now: UInt64)
    -> [CANFrame]?
  {
    let packet = TransportProtocol.dataPacket(transfer.sentPackets, of: transfer.message)
    transfer.sentPackets += 1
    return sendSystemMessage(packet, from: device, at: now)
  }

  // MARK: - Address claim

  /// Whether a device's address claim is in progress. When one has just
  /// ended, the device keeps the address and remembers where to stop trying
  /// next time.
  ///
  /// Ports `IsAddressClaimStarted`.
  mutating func isClaimingAddress(_ device: Int, at now: UInt64) -> Bool {
    guard let deadline = devices[device].claimDeadline else { return false }
    guard now >= deadline else { return true }
    devices[device].claimDeadline = nil
    devices[device].resetLastAddressToTry()
    return false
  }

  /// Claims a device's address, if the node is a full node.
  ///
  /// Ports `StartAddressClaim`.
  private mutating func startAddressClaim(_ device: Int, at now: UInt64) -> [CANFrame] {
    guard mode == .node else { return [] }
    devices[device].claimDeadline = nil
    let frames = addressClaimFrames(device)
    devices[device].claimDeadline = now + Self.addressClaimTimeout
    return frames
  }

  /// Handles another device's address claim.
  ///
  /// A claim for one of the node's addresses from a device with a higher
  /// NAME gets the address claimed again. Against a lower NAME the device
  /// moves to the next free address. Against its own NAME during a claim, it
  /// assumes it is clashing with an identical device and changes its device
  /// instance.
  ///
  /// Ports `HandleISOAddressClaim`.
  private mutating func handleAddressClaim(_ message: Message, at now: UInt64) -> [CANFrame] {
    guard let device = device(at: message.source) else { return [] }
    let claimant = ISOAddressClaim(message: message).name
    if devices[device].name < claimant {
      return addressClaimFrames(device)
    }
    if devices[device].name == claimant && isClaimingAddress(device, at: now) {
      devices[device].name.deviceInstance &+= 1
      events.append(.deviceInformationChanged(device: device))
    } else {
      moveToNextAddress(device)
    }
    return startAddressClaim(device, at: now)
  }

  /// Moves a device to a commanded address and claims it, if the command
  /// names the device's NAME and a new, valid address. Upstream only accepts
  /// the command by transport protocol, with exactly nine bytes: the NAME,
  /// then the address.
  ///
  /// Ports `HandleCommandedAddress`.
  private mutating func handleCommandedAddress(_ message: Message, at now: UInt64) -> [CANFrame] {
    guard message.isTransportProtocol, message.data.count == 9 else { return [] }
    var reader = MessageReader(message)
    let commandedName = DeviceName(rawValue: reader.readUInt64())
    let newAddress = reader.readUInt8()
    guard newAddress <= MessageFramer.maxBusAddress else { return [] }
    return recipients(of: message).flatMap { device -> [CANFrame] in
      guard devices[device].name == commandedName, devices[device].address != newAddress else {
        return []
      }
      devices[device].address = newAddress
      devices[device].resetLastAddressToTry()
      events.append(.addressChanged(device: device))
      return startAddressClaim(device, at: now)
    }
  }

  /// Moves a device to the next address to claim, wrapping from 251 to 0
  /// and skipping addresses its sibling devices hold. Once every address has
  /// been tried, the device has none.
  ///
  /// Ports `GetNextAddress`.
  private mutating func moveToNextAddress(_ device: Int, restartingFromFirstAddress: Bool = false) {
    let original = devices[device].address
    defer {
      if devices[device].address != original { events.append(.addressChanged(device: device)) }
    }
    repeat {
      let address = devices[device].address
      if address == Self.nullAddress {
        guard restartingFromFirstAddress else { return }
        devices[device].address = Self.firstClaimedAddress
        devices[device].resetLastAddressToTry()
      } else if address != devices[device].lastAddressToTry {
        devices[device].address = address == MessageFramer.maxBusAddress ? 0 : address + 1
      } else {
        devices[device].address = Self.nullAddress
        return
      }
    } while devices.indices.contains {
      $0 != device && devices[$0].address == devices[device].address
    }
  }

  // MARK: - Application requests

  /// Claims every device's address again, starting from 14 for a device
  /// without one.
  ///
  /// Ports `Restart`.
  mutating func restartAddressClaim(at now: UInt64) -> [CANFrame] {
    devices.indices.flatMap { index -> [CANFrame] in
      if devices[index].address == Self.nullAddress {
        moveToNextAddress(index, restartingFromFirstAddress: true)
      }
      return openState == .open ? startAddressClaim(index, at: now) : []
    }
  }

  /// Sends a device's address claim, to one device or all.
  ///
  /// Ports `SendIsoAddressClaim`.
  mutating func sendAddressClaim(from device: Int, to destination: UInt8, at now: UInt64)
    throws(NodeError) -> [CANFrame]
  {
    guard devices.indices.contains(device) else { throw .noSuchDevice(device) }
    return try send(
      ISOAddressClaim(name: devices[device].name).makeMessage(destination: destination),
      from: device, at: now)
  }

  /// Sends one of a device's PGN lists.
  ///
  /// Ports `SendTxPGNList` and `SendRxPGNList`.
  mutating func sendPGNList(
    _ kind: PGNList.Kind, from device: Int, to destination: UInt8, transportProtocol: Bool,
    at now: UInt64
  ) throws(NodeError) -> [CANFrame] {
    guard devices.indices.contains(device) else { throw .noSuchDevice(device) }
    var message =
      kind == .receive
      ? receiveList(of: device, to: destination) : transmitList(of: device, to: destination)
    message.isTransportProtocol = transportProtocol
    return try send(message, from: device, at: now)
  }

  /// Sends a heartbeat now, outside the schedule, with sequence number
  /// `nil`.
  ///
  /// Ports `SendHeartbeat(int)`.
  mutating func sendHeartbeat(from device: Int, at now: UInt64) throws(NodeError) -> [CANFrame] {
    guard devices.indices.contains(device) else { throw .noSuchDevice(device) }
    let period = devices[device].heartbeat?.period ?? devices[device].heartbeatInterval ?? 60000
    return try send(
      Heartbeat(interval: Double(period) / 1000, sequenceCounter: nil).makeMessage(), from: device,
      at: now)
  }

  /// Changes a device's heartbeat interval and offset, or turns its
  /// heartbeat off with an interval of `nil`. The interval is kept between 1
  /// and 655.32 seconds, and a change reschedules the next heartbeat.
  ///
  /// Ports `SetHeartbeatIntervalAndOffset`.
  mutating func setHeartbeat(
    of device: Int, interval: UInt64?, offset: UInt64?, at now: UInt64
  ) {
    guard let interval else {
      devices[device].heartbeat = nil
      devices[device].heartbeatInterval = nil
      return
    }
    let period = min(max(interval, 1000), 655_320)
    devices[device].heartbeatInterval = period
    guard let openTime else { return }
    if var schedule = devices[device].heartbeat {
      let newOffset = offset ?? schedule.offset
      guard period != schedule.period || newOffset != schedule.offset else { return }
      schedule.period = period
      schedule.offset = newOffset
      schedule.scheduleNext(at: now)
      devices[device].heartbeat = schedule
    } else {
      devices[device].heartbeat = HeartbeatSchedule(
        sync: openTime, offset: offset ?? Self.heartbeatOffset, period: period, now: now)
    }
    events.append(.deviceInformationChanged(device: device))
  }

  /// Sets a device's device and system instances, and claims its address
  /// with the new NAME 2 ms later.
  ///
  /// Ports `SetDeviceInformationInstances`.
  mutating func setInstances(
    of device: Int, lower: UInt8?, upper: UInt8?, system: UInt8?, at now: UInt64
  ) {
    let original = devices[device].name
    if let lower { devices[device].name.deviceInstanceLower = lower }
    if let upper { devices[device].name.deviceInstanceUpper = upper }
    if let system { devices[device].name.systemInstance = system }
    if devices[device].name != original {
      events.append(.deviceInformationChanged(device: device))
    }
    if openState == .open && mode == .node { devices[device].pendingClaim = now + 2 }
  }

  /// Ports `SendIsoAddressClaim`.
  mutating func addressClaimFrames(_ device: Int) -> [CANFrame] {
    var message = ISOAddressClaim(name: devices[device].name).makeMessage()
    message.source = devices[device].address
    guard let frames = try? devices[device].framer.frames(for: message) else { return [] }
    sentMessages.append(message)
    return frames
  }
}

extension ISOAddressClaim {
  /// Decodes a claim the assembler has already matched by PGN.
  fileprivate init(message: Message) {
    var reader = MessageReader(message)
    self.init(from: &reader)
  }
}
