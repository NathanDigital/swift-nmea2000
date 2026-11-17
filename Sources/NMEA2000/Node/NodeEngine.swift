// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The node's state machine, with no I/O: ``Node`` feeds it the time, the
/// result of opening the transport and received frames, and sends the frames
/// it returns.
///
/// Time is milliseconds since the node started. Like upstream on Arduino,
/// whose scheduler uses the 32-bit `millis()`, a deadline is reached at its
/// exact millisecond. The heartbeat is the exception: upstream schedules it
/// with a 64-bit timer that fires only once its deadline has passed.
///
/// Ports the open sequence, `SendMsg` checks, `ParseMessages`, address
/// claiming, the ISO transport protocol, ISO requests and the heartbeat of
/// `tNMEA2000`, for one device.
struct NodeEngine: Sendable {
  /// How long to wait after the transport opens before claiming an address.
  /// Upstream found some CAN controllers misbehave when sending straight
  /// away.
  static let openDelay: UInt64 = 200

  /// How long to wait before trying again when the transport fails to open.
  static let openRetryDelay: UInt64 = 1000

  /// How long an address claim must go unchallenged before the node uses
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

  /// What the node tells other devices about itself.
  struct DeviceInformation: Sendable {
    var productInformation = ProductInformation.default
    /// `nil` makes the node answer requests for it with a negative
    /// acknowledgement.
    var configurationInformation: ConfigurationInformation? = .default
    /// The PGNs the device transmits beyond the defaults.
    var transmitPGNs: [UInt32] = []
    /// The PGNs the device receives beyond the defaults.
    var receivePGNs: [UInt32] = []
    /// The heartbeat interval in milliseconds, or `nil` for none.
    var heartbeatInterval: UInt64? = 60000
    /// Answers ISO requests the node doesn't answer itself.
    var isoRequestHandler: Node.ISORequestHandler?
  }

  enum OpenState: Hashable {
    /// The transport isn't open; try to open it at the given time.
    case closed(retryAt: UInt64)
    /// The transport is open; claim an address at the given time.
    case waiting(until: UInt64)
    /// The node is running.
    case open
  }

  let mode: Node.Mode
  private(set) var openState = OpenState.closed(retryAt: 0)
  // Group function handlers (NodeEngine+GroupFunctions.swift) change these.
  var name: DeviceName
  var address: UInt8
  private var framer: MessageFramer
  private var assembler: MessageAssembler

  /// The last address to try before giving up, one before the address the
  /// node last held (upstream's `AddressClaimEndSource`).
  private var lastAddressToTry: UInt8 = 0

  /// When the address claim in progress ends, or `nil` if there isn't one.
  private var claimDeadline: UInt64?

  /// The message being sent by transport protocol, if any (upstream's
  /// `PendingTPMsg`).
  private var transfer: Transfer?

  var device: DeviceInformation

  /// When heartbeats are due, once the node is open (upstream's
  /// `HeartbeatScheduler`).
  var heartbeat: HeartbeatSchedule?

  /// When to send an address claim that was put off for a moment, if any
  /// (upstream's `PendingIsoAddressClaim`).
  var pendingClaim: UInt64?

  /// The devices on the bus, if the node keeps track of them.
  var deviceList: DeviceList?

  /// A heartbeat schedule synchronised to the time the node opened
  /// (upstream's `tN2kSyncScheduler`).
  struct HeartbeatSchedule {
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

  private struct Transfer {
    var message: Message
    /// How many data packets have been sent (`NextDTSequence`).
    var sentPackets = 0
    /// When to send the next broadcast packet, or give up waiting for a
    /// clear to send (`NextDTSendTime`).
    var deadline: UInt64

    var isBroadcast: Bool { message.destination == Message.broadcastAddress }
    var isComplete: Bool { sentPackets * 7 >= message.data.count }
  }

  init(
    mode: Node.Mode, address: UInt8, name: DeviceName, framer: MessageFramer,
    assembler: MessageAssembler, device: DeviceInformation = DeviceInformation()
  ) {
    self.mode = mode
    self.address = address
    self.name = name
    self.framer = framer
    self.assembler = assembler
    self.device = device
    resetLastAddressToTry()
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
  /// away the next time it runs, and claims its address again.
  mutating func transportClosed() {
    openState = .closed(retryAt: 0)
    claimDeadline = nil
    transfer = nil
    heartbeat = nil
    pendingClaim = nil
  }

  /// The next time ``poll(at:)`` has something to do, if any.
  var nextDeadline: UInt64? {
    switch openState {
    case .closed(let retryAt): retryAt
    case .waiting(let until): until
    case .open:
      [claimDeadline, transfer?.deadline, pendingClaim, heartbeat.map { $0.next + 1 }]
        .compactMap { $0 }.min()
    }
  }

  /// Advances timers, and returns any frames to send.
  ///
  /// Call it before ``send(_:at:)``, and at ``nextDeadline``.
  /// ``receive(_:at:)`` polls itself.
  mutating func poll(at now: UInt64) -> [CANFrame] {
    beforeReceiving(at: now) + afterReceiving(at: now)
  }

  /// What upstream's `ParseMessages` does before reading frames: open, and
  /// send pending messages.
  private mutating func beforeReceiving(at now: UInt64) -> [CANFrame] {
    switch openState {
    case .closed: return []
    case .waiting(let until):
      guard now >= until else { return [] }
      openState = .open
      // A device without an address starts again from the first one.
      if address == Self.nullAddress { moveToNextAddress(restartingFromFirstAddress: true) }
      if let period = device.heartbeatInterval {
        heartbeat = HeartbeatSchedule(
          sync: now, offset: Self.heartbeatOffset, period: period, now: now)
      }
      return startAddressClaim(at: now)
    case .open:
      _ = isClaimingAddress(at: now)
      var frames = continueTransfer(at: now)
      if let time = pendingClaim, now >= time {
        pendingClaim = nil
        frames += addressClaimFrames()
      }
      return frames
    }
  }

  /// What upstream's `ParseMessages` does after reading frames: send the
  /// heartbeat when it's due.
  ///
  /// Ports `SendHeartbeat`.
  private mutating func afterReceiving(at now: UInt64) -> [CANFrame] {
    guard mode == .node, var schedule = heartbeat, now > schedule.next,
      !isClaimingAddress(at: now)
    else { return [] }
    schedule.scheduleNext(at: now)
    let message = Heartbeat(
      interval: Double(schedule.period) / 1000, sequenceCounter: schedule.sequence
    ).makeMessage()
    schedule.sequence = schedule.sequence >= 252 ? 0 : schedule.sequence + 1
    heartbeat = schedule
    return sendSystemMessage(message, at: now) ?? []
  }

  // MARK: - Receiving

  /// Handles a received frame.
  ///
  /// Frames received before the node opens are discarded, as upstream reads
  /// out what the CAN controller collected while starting.
  ///
  /// - Returns: The frames to send in response, and the message the frame
  ///   completes, if any.
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
    // Upstream also counts 252 and 253 as local, but a node there can't send
    // replies, so they make no difference.
    let localAddress = address <= MessageFramer.maxBusAddress ? address : nil
    let reception = assembler.receive(
      frame, at: UInt32(truncatingIfNeeded: now), localAddress: localAddress)
    var frames = reception.replies.flatMap { sendSystemMessage($0, at: now) ?? [] }
    if let control = reception.control {
      frames += handleTransportControl(control, at: now)
    }
    guard let assembled = reception.assembled else { return (frames, nil) }
    if assembled.isSystemMessage && mode == .node {
      switch assembled.message.pgn {
      case ISOAddressClaim.pgn: frames += handleAddressClaim(assembled.message, at: now)
      case ISORequest.pgn: frames += handleISORequest(assembled.message, at: now)
      case Self.commandedAddressPGN: frames += handleCommandedAddress(assembled.message, at: now)
      case GroupFunction.pgn: frames += handleGroupFunction(assembled.message, at: now)
      default: break
      }
    }
    return (frames, assembled.message)
  }

  // MARK: - Sending

  /// Returns the frames that carry a message from this node.
  ///
  /// The message's source is replaced with the node's address. A message
  /// marked ``Message/isTransportProtocol`` that doesn't fit a single frame
  /// starts a transport protocol session, which sends its data packets
  /// later; the frames returned announce it.
  ///
  /// - Throws: ``NodeError`` if the node can't send the message now.
  mutating func send(_ message: Message, at now: UInt64) throws(NodeError) -> [CANFrame] {
    guard openState == .open else { throw .notOpen }
    guard mode != .listenOnly else { throw .listenOnly }
    var message = message
    message.source = address
    let isClaim = message.pgn == ISOAddressClaim.pgn
    guard address <= MessageFramer.maxBusAddress || isClaim else { throw .noAddress }
    guard isClaim || !isClaimingAddress(at: now) else { throw .claimingAddress }
    do {
      try MessageFramer.validate(message)
    } catch {
      throw .invalidMessage(error)
    }
    if message.isTransportProtocol
      && (message.data.count > CANFrame.maxDataCount || framer.catalog.isFastPacket(message.pgn))
    {
      return try startTransfer(message, at: now)
    }
    do {
      return try framer.frames(for: message)
    } catch {
      throw .invalidMessage(error)
    }
  }

  /// Sends a message the node sends on its own behalf, only as a full node,
  /// and returns `nil` if it can't be sent now.
  private mutating func sendSystemMessage(_ message: Message, at now: UInt64) -> [CANFrame]? {
    guard mode == .node else { return nil }
    return try? send(message, at: now)
  }

  // MARK: - ISO requests

  /// Answers an ISO request sent to the node or broadcast, unless the node
  /// is claiming its address.
  ///
  /// Ports `HandleISORequest` and `RespondISORequest`.
  private mutating func handleISORequest(_ message: Message, at now: UInt64) -> [CANFrame] {
    let isAddressed = message.destination != Message.broadcastAddress
    guard !isAddressed || message.destination == address,
      message.destination != Self.nullAddress
    else { return [] }
    // Upstream ignores a request it can't parse, which asks for PGN 0.
    let requested = (try? ISORequest(message))?.requestedPGN ?? 0
    guard !isClaimingAddress(at: now) else { return [] }
    let requester = message.source
    switch requested {
    case ISOAddressClaim.pgn:
      return addressClaimFrames()
    case PGNList.pgn:
      return sendAll([transmitList(to: requester), receiveList(to: requester)], at: now)
    case ProductInformation.pgn:
      return sendAll([device.productInformation.makeMessage()], at: now)
    case ConfigurationInformation.pgn:
      return sendAll([configurationReply(to: Message.broadcastAddress)], at: now)
    default:
      if let handler = device.isoRequestHandler {
        if !isAddressed && Self.ignoredBroadcastRequests.contains(requested) { return [] }
        if let replies = handler(requested, requester) { return sendAll(replies, at: now) }
      }
      guard isAddressed else { return [] }
      return sendAll(
        [ISOAcknowledgement(control: 1, pgn: requested).makeMessage(destination: requester)],
        at: now)
    }
  }

  /// Sends messages, dropping any that can't be sent.
  mutating func sendAll(_ messages: [Message], at now: UInt64) -> [CANFrame] {
    messages.flatMap { (try? send($0, at: now)) ?? [] }
  }

  // MARK: - Transport protocol

  /// Starts sending a message by transport protocol: a BAM followed by a
  /// data packet every 50 ms, or a request to send that the receiver must
  /// answer within 50 ms.
  ///
  /// Ports `StartSendTPMessage`.
  private mutating func startTransfer(_ message: Message, at now: UInt64) throws(NodeError)
    -> [CANFrame]
  {
    guard transfer == nil else { throw .transferInProgress }
    guard mode == .node else { throw .notAFullNode }
    var message = message
    // A PDU2 PGN can only be broadcast (`CheckDestination`).
    if message.pgn & 0xff != 0 { message.destination = Message.broadcastAddress }
    transfer = Transfer(message: message, deadline: now + TransportProtocol.packetInterval)
    return sendSystemMessage(TransportProtocol.start(message), at: now) ?? []
  }

  /// Sends the next broadcast packet when it's due, or gives up on a
  /// receiver that stopped answering.
  ///
  /// Ports `SendPendingTPMessage`.
  private mutating func continueTransfer(at now: UInt64) -> [CANFrame] {
    guard var transfer, now >= transfer.deadline else { return [] }
    guard transfer.isBroadcast else {
      self.transfer = nil
      return []
    }
    let frames = sendDataPacket(&transfer, at: now) ?? []
    transfer.deadline = now + TransportProtocol.packetInterval
    self.transfer = transfer.isComplete ? nil : transfer
    return frames
  }

  /// Handles a clear to send, acknowledgement or abort from the receiver.
  ///
  /// Ports the sending side of `TestHandleTPMessage`.
  private mutating func handleTransportControl(
    _ control: MessageAssembler.TransportControl, at now: UInt64
  ) -> [CANFrame] {
    guard var transfer, !transfer.isBroadcast else { return [] }
    guard control.pgn == transfer.message.pgn, control.control == .clearToSend else {
      self.transfer = nil
      return []
    }
    var frames: [CANFrame] = []
    // A clear to send for no packets asks the sender to wait.
    if control.packets > 0 {
      guard Int(control.nextPacket) - 1 == transfer.sentPackets else {
        self.transfer = nil
        return []
      }
      for _ in 0..<control.packets where !transfer.isComplete {
        guard let packet = sendDataPacket(&transfer, at: now) else {
          self.transfer = nil
          return frames
        }
        frames += packet
      }
    }
    transfer.deadline = now + TransportProtocol.clearToSendTimeout
    self.transfer = transfer
    return frames
  }

  /// Sends the next data packet, returning `nil` if it can't be sent.
  ///
  /// Ports `SendTPDT`.
  private mutating func sendDataPacket(_ transfer: inout Transfer, at now: UInt64) -> [CANFrame]? {
    let packet = TransportProtocol.dataPacket(transfer.sentPackets, of: transfer.message)
    transfer.sentPackets += 1
    return sendSystemMessage(packet, at: now)
  }

  // MARK: - Address claim

  /// Whether an address claim is in progress. When one has just ended, the
  /// node keeps the address and remembers where to stop trying next time.
  ///
  /// Ports `IsAddressClaimStarted`.
  mutating func isClaimingAddress(at now: UInt64) -> Bool {
    guard let deadline = claimDeadline else { return false }
    guard now >= deadline else { return true }
    claimDeadline = nil
    resetLastAddressToTry()
    return false
  }

  /// Claims the node's address, if it is a full node.
  ///
  /// Ports `StartAddressClaim`.
  private mutating func startAddressClaim(at now: UInt64) -> [CANFrame] {
    guard mode == .node else { return [] }
    claimDeadline = nil
    let frames = addressClaimFrames()
    claimDeadline = now + Self.addressClaimTimeout
    return frames
  }

  /// Handles another device's address claim.
  ///
  /// A claim for this node's address from a device with a higher NAME gets
  /// the address claimed again. Against a lower NAME the node moves to the
  /// next free address. Against its own NAME during a claim, it assumes it
  /// is clashing with an identical device and changes its device instance.
  ///
  /// Ports `HandleISOAddressClaim`.
  private mutating func handleAddressClaim(_ message: Message, at now: UInt64) -> [CANFrame] {
    guard message.source != Self.nullAddress, message.source == address else { return [] }
    let claimant = ISOAddressClaim(message: message).name
    if name < claimant {
      return addressClaimFrames()
    }
    if name == claimant && isClaimingAddress(at: now) {
      name.deviceInstance &+= 1
    } else {
      moveToNextAddress()
    }
    return startAddressClaim(at: now)
  }

  /// Moves to a commanded address and claims it, if the command names this
  /// node's NAME and a new, valid address. Upstream only accepts the command
  /// by transport protocol, with exactly nine bytes: the NAME, then the
  /// address.
  ///
  /// Ports `HandleCommandedAddress`.
  private mutating func handleCommandedAddress(_ message: Message, at now: UInt64) -> [CANFrame] {
    guard message.isTransportProtocol, message.data.count == 9,
      message.destination == Message.broadcastAddress
        || (message.destination == address && address != Self.nullAddress)
    else { return [] }
    var reader = MessageReader(message)
    let commandedName = DeviceName(rawValue: reader.readUInt64())
    let newAddress = reader.readUInt8()
    guard newAddress <= MessageFramer.maxBusAddress, commandedName == name, newAddress != address
    else { return [] }
    address = newAddress
    resetLastAddressToTry()
    return startAddressClaim(at: now)
  }

  /// Moves to the next address to claim, wrapping from 251 to 0. Once every
  /// address has been tried, the node has none.
  ///
  /// Ports `GetNextAddress`.
  private mutating func moveToNextAddress(restartingFromFirstAddress: Bool = false) {
    if address == Self.nullAddress {
      guard restartingFromFirstAddress else { return }
      address = Self.firstClaimedAddress
      resetLastAddressToTry()
    } else if address != lastAddressToTry {
      address = address == MessageFramer.maxBusAddress ? 0 : address + 1
    } else {
      address = Self.nullAddress
    }
  }

  /// Ports `UpdateAddressClaimEndSource`.
  private mutating func resetLastAddressToTry() {
    lastAddressToTry = address > 0 ? address - 1 : MessageFramer.maxBusAddress
  }

  /// Ports `SendIsoAddressClaim`.
  mutating func addressClaimFrames() -> [CANFrame] {
    var message = ISOAddressClaim(name: name).makeMessage()
    message.source = address
    return (try? framer.frames(for: message)) ?? []
  }
}

extension ISOAddressClaim {
  /// Decodes a claim the assembler has already matched by PGN.
  fileprivate init(message: Message) {
    var reader = MessageReader(message)
    self.init(from: &reader)
  }
}
