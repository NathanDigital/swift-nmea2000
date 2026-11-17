// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Reassembles received CAN frames into messages.
///
/// Single frames become messages straight away. Fast packets are collected in
/// a small set of buffers, one per PGN, source and destination, until all
/// their bytes have arrived. A frame out of sequence discards that fast
/// packet; a continuation frame with no first frame is ignored. When every
/// buffer is busy, a new fast packet takes the oldest buffer once it is at
/// least 100 ms old, and is dropped before then.
///
/// Time is a free-running millisecond counter that may wrap, like upstream's
/// `millis()`. Each message's ``Message/timestamp`` is the time its first
/// frame arrived.
///
/// ISO transport protocol frames are passed through as single-frame system
/// messages; the node reassembles transport protocol sessions.
///
/// Ports `tNMEA2000::SetN2kCANBufMsg` and `tNMEA2000::FindFreeCANMsgIndex`.
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
    let header = CANIdentifier(frameID: frame.id)
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
        guard data.count >= 2, let found = freeBuffer(for: header, at: time) else { return nil }
        buffers[found].start(header, kind: kind, at: time)
        buffers[found].append(data.dropFirst(2))
        buffers[found].lastFrame = counter
        buffers[found].expectedCount = Int(data[1])
        index = found
      }
    } else {
      guard let found = freeBuffer(for: header, at: time) else { return nil }
      buffers[found].start(header, kind: kind, at: time)
      buffers[found].append(data[...])
      buffers[found].expectedCount = data.count
      index = found
    }

    let buffer = buffers[index]
    guard buffer.message.data.count >= buffer.expectedCount else { return nil }
    buffers[index] = Buffer()
    var message = buffer.message
    message.data.removeLast(message.data.count - buffer.expectedCount)
    return Assembled(message: message, isSystemMessage: buffer.isSystem)
  }

  /// The buffer for a new message: a free one, one already holding a message
  /// with the same header, or the oldest busy one once it has timed out.
  private mutating func freeBuffer(for header: CANIdentifier, at time: UInt32) -> Int? {
    var oldestTime = time
    var oldestIndex: Int?
    for index in buffers.indices {
      let buffer = buffers[index]
      if buffer.isFree
        || (buffer.message.pgn == header.pgn && buffer.message.source == header.source
          && buffer.message.destination == header.destination)
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
