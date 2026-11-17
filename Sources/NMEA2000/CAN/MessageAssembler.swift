// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Reassembles received CAN frames into messages.
///
/// Single frames become messages straight away. Fast packets and ISO
/// transport protocol sessions are collected in a small set of buffers, one
/// per PGN, source and destination, until all their bytes have arrived. A
/// frame out of sequence discards its message; a continuation frame with no
/// first frame is ignored. When every buffer is busy, a new message takes
/// the oldest buffer once it is at least 100 ms old, and is dropped before
/// then.
///
/// The transport protocol's own frames are consumed, not delivered. The
/// assembler reassembles every session it sees, including those between
/// other devices, but doesn't answer requests to send; ``Node`` does that.
/// A message received by transport protocol has priority 7, as its frames
/// don't carry the message's priority.
///
/// Time is a free-running millisecond counter that may wrap, like upstream's
/// `millis()`. Each message's ``Message/timestamp`` is the time its first
/// frame arrived, or for the transport protocol, its last data packet.
///
/// Ports `tNMEA2000::SetN2kCANBufMsg`, `tNMEA2000::FindFreeCANMsgIndex` and
/// the receiving side of `tNMEA2000::TestHandleTPMessage`.
public struct MessageAssembler: Sendable {
  /// A message reassembled from frames.
  public struct Assembled: Sendable, Hashable {
    /// The message.
    public var message: Message
    /// Whether the message is a network management message (address claim,
    /// ISO request, group function and the like) that the node handles
    /// itself.
    public var isSystemMessage: Bool
  }

  /// How long a buffer must be busy before a new fast packet may take it,
  /// in milliseconds (`Max_N2kMsgBuf_Time`).
  public static let bufferTimeout: UInt32 = 100

  /// The catalog that decides which PGNs arrive as fast packets.
  public var catalog: PGNCatalog

  /// Whether to drop messages whose PGN isn't in the catalog, apart from
  /// proprietary fast packets' framing. Upstream's default is `false`.
  public var handlesOnlyKnownMessages: Bool

  private var buffers: [Buffer]

  /// Drops every message being reassembled, as when the bus connection is
  /// lost and the frames that follow can't belong to them.
  public mutating func reset() {
    buffers = Array(repeating: Buffer(), count: buffers.count)
  }

  /// Creates an assembler.
  ///
  /// - Parameters:
  ///   - catalog: The catalog that decides which PGNs arrive as fast packets.
  ///   - bufferCount: How many messages can be reassembled at once. Upstream
  ///     defaults to 5 (`SetN2kCANMsgBufSize`).
  ///   - handlesOnlyKnownMessages: Whether to drop messages whose PGN isn't
  ///     in the catalog.
  public init(
    catalog: PGNCatalog = PGNCatalog(), bufferCount: Int = 5, handlesOnlyKnownMessages: Bool = false
  ) {
    self.catalog = catalog
    self.handlesOnlyKnownMessages = handlesOnlyKnownMessages
    buffers = Array(repeating: Buffer(), count: max(bufferCount, 1))
  }

  /// Adds a received frame, and returns the message it completes, if any.
  ///
  /// A fast-packet frame too short to hold its frame counter (or, for a
  /// first frame, the payload length) is ignored. Upstream reads leftover
  /// bytes from its frame buffer in that case.
  ///
  /// - Parameters:
  ///   - frame: The received frame.
  ///   - time: The time the frame arrived, in milliseconds.
  /// - Returns: The completed message, or `nil` if the frame doesn't complete
  ///   one.
  public mutating func receive(_ frame: CANFrame, at time: UInt32) -> Assembled? {
    receive(frame, at: time, localAddress: nil).assembled
  }

  /// What a received frame produced, for a node at a local address.
  struct Reception: Sendable {
    /// The message the frame completes, if any.
    var assembled: Assembled?
    /// Transport protocol replies the node owes the sender.
    var replies: [Message] = []
    /// A transport protocol control (clear to send, acknowledgement or
    /// abort) sent to the local address, for the node's sending session.
    var control: TransportControl?
  }

  /// A transport protocol control message sent to the node.
  struct TransportControl: Sendable, Hashable {
    var control: TransportProtocol.Control
    var pgn: UInt32
    /// The packet count of a clear to send.
    var packets: UInt8
    /// The next packet number of a clear to send.
    var nextPacket: UInt8
  }

  /// Adds a received frame for a node at `localAddress`, and returns the
  /// message it completes and the transport protocol replies to send.
  mutating func receive(_ frame: CANFrame, at time: UInt32, localAddress: UInt8?) -> Reception {
    let header = CANIdentifier(frameID: frame.id)
    switch header.pgn {
    case TransportProtocol.connectionManagementPGN:
      return receiveConnectionManagement(frame.data, header, at: time, localAddress: localAddress)
    case TransportProtocol.dataTransferPGN:
      return receiveDataPacket(frame.data, header, at: time, localAddress: localAddress)
    default:
      return Reception(assembled: receiveFrame(frame, header, at: time))
    }
  }

  private mutating func receiveFrame(_ frame: CANFrame, _ header: CANIdentifier, at time: UInt32)
    -> Assembled?
  {
    let kind = catalog.classify(header.pgn)
    guard kind.isKnown || !handlesOnlyKnownMessages else { return nil }
    let data = frame.data

    let index: Int
    if kind.isFastPacket {
      guard let counter = data.first else { return nil }
      if counter & 0x1f != 0 {
        // A continuation frame: find the fast packet it belongs to.
        guard
          let found = buffers.firstIndex(where: {
            $0.message.pgn == header.pgn && $0.message.source == header.source
              && $0.message.framing != .transportProtocol
          })
        else { return nil }
        guard buffers[found].lastFrame &+ 1 == counter else {
          buffers[found] = Buffer()
          return nil
        }
        buffers[found].lastFrame = counter
        buffers[found].append(data.dropFirst())
        index = found
      } else {
        guard data.count >= 2, let found = freeBuffer(for: header, transport: false, at: time)
        else { return nil }
        buffers[found].start(header, kind: kind, at: time)
        buffers[found].append(data.dropFirst(2))
        buffers[found].lastFrame = counter
        buffers[found].expectedCount = Int(data[1])
        index = found
      }
    } else {
      guard let found = freeBuffer(for: header, transport: false, at: time) else { return nil }
      buffers[found].start(header, kind: kind, at: time)
      buffers[found].append(data[...])
      buffers[found].expectedCount = data.count
      index = found
    }

    return complete(index)
  }

  /// Returns the buffer's message and frees the buffer, if all its bytes
  /// have arrived.
  private mutating func complete(_ index: Int) -> Assembled? {
    let buffer = buffers[index]
    guard buffer.message.data.count >= buffer.expectedCount else { return nil }
    buffers[index] = Buffer()
    var message = buffer.message
    message.data.removeLast(message.data.count - buffer.expectedCount)
    return Assembled(message: message, isSystemMessage: buffer.isSystem)
  }

  // MARK: - Transport protocol

  /// Handles a connection management frame: a BAM or request to send starts
  /// reassembling a message; other controls sent to the local address go to
  /// the node's sending session.
  ///
  /// A frame shorter than eight bytes is ignored. Upstream reads leftover
  /// bytes from its frame buffer in that case.
  private mutating func receiveConnectionManagement(
    _ data: [UInt8], _ header: CANIdentifier, at time: UInt32, localAddress: UInt8?
  ) -> Reception {
    guard data.count >= 8, let control = TransportProtocol.Control(rawValue: data[0]) else {
      return Reception()
    }
    let pgn = UInt32(data[5]) | UInt32(data[6]) << 8 | UInt32(data[7]) << 16
    let isForLocal = localAddress != nil && header.destination == localAddress
    switch control {
    case .broadcastAnnounce, .requestToSend:
      let byteCount = Int(data[1]) | Int(data[2]) << 8
      // Upstream takes the packet count as the most packets to ask for at once.
      let packets = data[3]
      let mustReply = control == .requestToSend && isForLocal
      let busy =
        mustReply
        ? [TransportProtocol.abort(pgn: pgn, to: header.source, reason: .busy)] : []
      let messageHeader = CANIdentifier(
        priority: TransportProtocol.receivedPriority, pgn: pgn, source: header.source,
        destination: header.destination)
      guard let index = freeBuffer(for: messageHeader, transport: true, at: time) else {
        return Reception(replies: busy)
      }
      let kind = catalog.classify(pgn)
      guard byteCount < Message.maxDataCount, kind.isKnown || !handlesOnlyKnownMessages else {
        return Reception(replies: busy)
      }
      buffers[index].start(messageHeader, kind: kind, at: time)
      buffers[index].message.framing = .transportProtocol
      buffers[index].expectedCount = byteCount
      buffers[index].lastFrame = 0
      guard mustReply else { return Reception() }
      buffers[index].maxPackets = packets
      buffers[index].packetsPerClearToSend = TransportProtocol.clearToSendPackets(packets)
      return Reception(replies: [
        TransportProtocol.clearToSend(pgn: pgn, to: header.source, packets: packets, next: 1)
      ])
    case .clearToSend, .endOfMessageAcknowledgement, .abort:
      guard isForLocal else { return Reception() }
      return Reception(
        control: TransportControl(control: control, pgn: pgn, packets: data[1], nextPacket: data[2])
      )
    }
  }

  /// Handles a data packet: adds it to the session from the same source to
  /// the same destination, asking for more packets or acknowledging the
  /// message when the session is with the local address.
  private mutating func receiveDataPacket(
    _ data: [UInt8], _ header: CANIdentifier, at time: UInt32, localAddress: UInt8?
  ) -> Reception {
    guard let sequence = data.first,
      let index = buffers.firstIndex(where: {
        !$0.isFree && $0.message.framing == .transportProtocol
          && $0.message.destination == header.destination && $0.message.source == header.source
      })
    else { return Reception() }
    let isForLocal = localAddress != nil && header.destination == localAddress
    let buffer = buffers[index]
    let repliesExpected = buffer.packetsPerClearToSend > 0 && isForLocal
    let pgn = buffer.message.pgn
    guard buffer.lastFrame &+ 1 == sequence else {
      buffers[index] = Buffer()
      return Reception(
        replies: repliesExpected
          ? [TransportProtocol.abort(pgn: pgn, to: header.source, reason: .timeout)] : [])
    }
    buffers[index].append(data.dropFirst())
    buffers[index].lastFrame = sequence
    // Sessions are slow, so each packet restarts the buffer's timeout.
    buffers[index].message.timestamp = time
    if let assembled = complete(index) {
      return Reception(
        assembled: assembled,
        replies: repliesExpected
          ? [
            TransportProtocol.endOfMessage(
              pgn: pgn, to: header.source, byteCount: buffer.expectedCount, packets: sequence)
          ] : [])
    }
    guard repliesExpected, sequence % buffer.packetsPerClearToSend == 0 else {
      return Reception()
    }
    return Reception(replies: [
      TransportProtocol.clearToSend(
        pgn: pgn, to: header.source, packets: buffer.maxPackets, next: sequence &+ 1)
    ])
  }

  // MARK: - Buffers

  /// The buffer for a new message: a free one, one already holding a message
  /// with the same header (and the same kind, fast packet or transport
  /// protocol), or the oldest busy one once it has timed out.
  private mutating func freeBuffer(for header: CANIdentifier, transport: Bool, at time: UInt32)
    -> Int?
  {
    var oldestTime = time
    var oldestIndex: Int?
    for index in buffers.indices {
      let buffer = buffers[index]
      if buffer.isFree
        || (buffer.message.pgn == header.pgn && buffer.message.source == header.source
          && buffer.message.destination == header.destination
          && (buffer.message.framing == .transportProtocol) == transport)
      {
        return index
      }
      if isTime(buffer.message.timestamp, before: oldestTime) {
        oldestIndex = index
        oldestTime = buffer.message.timestamp
      }
    }
    guard let oldestIndex, hasElapsed(Self.bufferTimeout, since: oldestTime, at: time) else {
      return nil
    }
    buffers[oldestIndex] = Buffer()
    return oldestIndex
  }

  /// One message being reassembled (upstream's `tN2kCANMsg`).
  private struct Buffer: Sendable {
    var isFree = true
    var isSystem = false
    var message = Message(pgn: 0, priority: 0, source: 0)
    var expectedCount = 0
    var lastFrame: UInt8 = 0
    /// For a transport protocol session with the node: the packet count
    /// from the request to send, and how many packets each clear to send
    /// asks for. Zero for other messages.
    var maxPackets: UInt8 = 0
    var packetsPerClearToSend: UInt8 = 0

    mutating func start(_ header: CANIdentifier, kind: PGNCatalog.Classification, at time: UInt32) {
      isFree = false
      isSystem = kind.isSystem
      message = Message(
        pgn: header.pgn, priority: header.priority, source: header.source,
        destination: header.destination, timestamp: time)
    }

    /// Appends bytes, up to the largest payload a message can hold.
    mutating func append(_ bytes: ArraySlice<UInt8>) {
      message.data += bytes.prefix(Message.maxDataCount - message.data.count)
    }
  }
}

/// Whether `first` is before `second` on a wrapping millisecond clock
/// (upstream's `N2kIsTimeBefore`, which also counts equal times).
func isTime(_ first: UInt32, before second: UInt32) -> Bool {
  second &- first < UInt32(Int32.max)
}

/// Whether `interval` milliseconds have passed since `start` at time `now`
/// on a wrapping millisecond clock (upstream's `N2kHasElapsed`).
func hasElapsed(_ interval: UInt32, since start: UInt32, at now: UInt32) -> Bool {
  now &- (start &+ interval) < UInt32(Int32.max)
}
