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
/// exact millisecond.
///
/// Ports the open sequence, `SendMsg` checks, `ParseMessages`, address
/// claiming and the ISO transport protocol of `tNMEA2000`, for one device.
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
  private(set) var name: DeviceName
  private(set) var address: UInt8
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
    assembler: MessageAssembler
  ) {
    self.mode = mode
    self.address = address
    self.name = name
    self.framer = framer
    self.assembler = assembler
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
  }

  /// The next time ``poll(at:)`` has something to do, if any.
  var nextDeadline: UInt64? {
    switch openState {
    case .closed(let retryAt): retryAt
    case .waiting(let until): until
    case .open: [claimDeadline, transfer?.deadline].compactMap { $0 }.min()
    }
  }

  /// Advances timers, and returns any frames to send.
  ///
  /// Call it before ``receive(_:at:)`` and ``send(_:at:)``, and at
  /// ``nextDeadline``.
  mutating func poll(at now: UInt64) -> [CANFrame] {
    switch openState {
    case .closed: return []
    case .waiting(let until):
      guard now >= until else { return [] }
      openState = .open
      // A device without an address starts again from the first one.
      if address == Self.nullAddress { moveToNextAddress(restartingFromFirstAddress: true) }
      return startAddressClaim(at: now)
    case .open:
      _ = isClaimingAddress(at: now)
      return continueTransfer(at: now)
    }
  }

  // MARK: - Receiving

  /// Handles a received frame.
  ///
  /// Frames received before the node opens are discarded, as upstream reads
  /// out what the CAN controller collected while starting.
  ///
  /// - Returns: The frames to send in response, and the message the frame
  ///   completes, if any.
  mutating func receive(_ frame: CANFrame, at now: UInt64) -> (
    frames: [CANFrame], message: Message?
  ) {
    guard openState == .open else { return ([], nil) }
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
  private mutating func isClaimingAddress(at now: UInt64) -> Bool {
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
  private mutating func addressClaimFrames() -> [CANFrame] {
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
