// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The Actisense serial format, which NMEA 2000 gateways such as the NGT-1
/// and many PC programs use to carry whole messages over a serial port.
///
/// A message is framed by DLE STX (`0x10 0x02`) and DLE ETX (`0x10 0x03`),
/// with any `0x10` inside doubled. The body is a type byte, a length,
/// the priority, PGN, destination, source, a time stamp, the payload length
/// and payload, and a checksum that makes the unescaped body sum to zero.
///
/// These are pure codecs: they turn messages into bytes and bytes into
/// messages, and leave the serial port to the caller.
public enum Actisense {
  static let escape: UInt8 = 0x10
  static let startOfText: UInt8 = 0x02
  static let endOfText: UInt8 = 0x03

  /// The type of a received NMEA 2000 message.
  static let messageType: UInt8 = 0x93

  /// The type of a message sent to the gateway to transmit, which carries no
  /// source or time stamp.
  static let sendType: UInt8 = 0x94

  /// Encodes a message.
  ///
  /// The message's ``Message/timestamp`` is the time stamp.
  ///
  /// Ports `tN2kMsg::SendInActisenseFormat`, with one deliberate fix:
  /// upstream counts its output with an 8-bit index, so a message that
  /// needs more than 255 bytes once escaped comes out corrupted. This port
  /// writes the whole message.
  ///
  /// - Throws: ``GatewayError/missingPGN`` or ``GatewayError/emptyPayload``,
  ///   which upstream refuses to write, or
  ///   ``GatewayError/payloadTooLong(count:)`` for a payload longer than
  ///   ``Message/maxDataCount``, which upstream's message can't hold and
  ///   readers reject.
  public static func encode(_ message: Message) throws(GatewayError) -> [UInt8] {
    try GatewayError.check(message)
    guard !message.data.isEmpty else { throw .emptyPayload }
    let count = message.data.count
    let time = message.timestamp
    let body: [UInt8] =
      [
        messageType, UInt8(truncatingIfNeeded: count + 11), message.priority,
        UInt8(truncatingIfNeeded: message.pgn), UInt8(truncatingIfNeeded: message.pgn >> 8),
        UInt8(truncatingIfNeeded: message.pgn >> 16), message.destination, message.source,
        UInt8(truncatingIfNeeded: time), UInt8(truncatingIfNeeded: time >> 8),
        UInt8(truncatingIfNeeded: time >> 16), UInt8(truncatingIfNeeded: time >> 24),
        UInt8(truncatingIfNeeded: count),
      ] + message.data
    var bytes: [UInt8] = [escape, startOfText]
    for byte in body + [checksum(of: body)] {
      bytes.append(byte)
      if byte == escape { bytes.append(escape) }
    }
    return bytes + [escape, endOfText]
  }

  /// The byte that makes the body sum to zero.
  static func checksum(of body: some Sequence<UInt8>) -> UInt8 {
    0 &- body.reduce(0, &+)
  }

  /// Finds messages in a stream of Actisense bytes.
  ///
  /// Feed it bytes as they arrive from the serial port, in any chunks; it
  /// returns each message once its last byte is in. Bytes outside a message are
  /// skipped, and a message with a bad length or checksum is dropped.
  ///
  /// Ports `tActisenseReader`, reading every byte as `GetMessageFromStream`
  /// does with its default `ReadOut` of `true`. A message's priority keeps
  /// its low three bits, as ``Message`` holds them.
  public struct Decoder: Sendable {
    /// The most bytes a message body may take (`MAX_STREAM_MSG_BUF_LEN`).
    static let bufferCount = 300

    /// The source given to a message sent to the gateway (type `0x94`),
    /// which doesn't carry one.
    public var defaultSource: UInt8

    private var buffer: [UInt8] = []
    private var sum: UInt8 = 0
    private var isStartOfTextReceived = false
    private var isMessageComing = false
    private var isEscapeReceived = false

    /// Creates a decoder.
    ///
    /// - Parameter defaultSource: The source given to messages that don't
    ///   carry one. Upstream's default is 65.
    public init(defaultSource: UInt8 = 65) {
      self.defaultSource = defaultSource
    }

    /// Adds bytes, and returns the messages they complete.
    ///
    /// - Parameters:
    ///   - bytes: Bytes received from the serial port.
    ///   - time: The time stamp for messages that don't carry one, in
    ///     milliseconds.
    public mutating func decode(_ bytes: some Sequence<UInt8>, at time: UInt32) -> [Message] {
      bytes.compactMap { decode($0, at: time) }
    }

    /// Adds one byte, and returns the message it completes, if any.
    ///
    /// Ports `tActisenseReader::GetMessageFromStream`.
    public mutating func decode(_ byte: UInt8, at time: UInt32) -> Message? {
      guard isMessageComing else {
        if byte == Actisense.startOfText {
          let isStart = isEscapeReceived
          isStartOfTextReceived = false
          if isStart {
            clear()
            isStartOfTextReceived = true
          }
        } else {
          isEscapeReceived = byte == Actisense.escape
          if isStartOfTextReceived {
            isStartOfTextReceived = false
            isMessageComing = true
            append(byte)
          }
        }
        return nil
      }
      guard isEscapeReceived else {
        if byte == Actisense.escape {
          isEscapeReceived = true
        } else if !append(byte) {
          clear()
        }
        return nil
      }
      switch byte {
      case Actisense.escape:
        isEscapeReceived = false
        if !append(byte) { clear() }
        return nil
      case Actisense.endOfText:
        let message =
          buffer.first == Actisense.messageType || buffer.first == Actisense.sendType
          ? checkedMessage(at: time) : nil
        clear()
        return message
      case Actisense.startOfText:
        clear()
        isStartOfTextReceived = true
        return nil
      default:
        clear()
        return nil
      }
    }

    private mutating func clear() {
      buffer.removeAll(keepingCapacity: true)
      sum = 0
      isStartOfTextReceived = false
      isMessageComing = false
      isEscapeReceived = false
    }

    /// Adds a byte to the body, keeping the checksum's sum. Returns `false` if
    /// the body is full.
    ///
    /// Ports `AddByteToBuffer`.
    @discardableResult
    private mutating func append(_ byte: UInt8) -> Bool {
      guard buffer.count < Self.bufferCount else { return false }
      buffer.append(byte)
      // The checksum byte, which follows `length` more bytes, isn't summed.
      if !buffer.indices.contains(1) || Int(buffer[1]) + 3 != buffer.count { sum &+= byte }
      return true
    }

    /// The message in the buffer, if its length and checksum are right.
    ///
    /// Ports `tActisenseReader::CheckMessage`.
    private func checkedMessage(at time: UInt32) -> Message? {
      guard buffer.indices.contains(1), buffer.count == Int(buffer[1]) + 3,
        0 &- sum == buffer[buffer.count - 1]
      else { return nil }
      let isReceived = buffer[0] == Actisense.messageType
      let headerCount = isReceived ? 13 : 8
      guard buffer.count >= headerCount + 1 else { return nil }
      let priority = buffer[2]
      let pgn = UInt32(buffer[3]) | UInt32(buffer[4]) << 8 | UInt32(buffer[5]) << 16
      let destination = buffer[6]
      let source = isReceived ? buffer[7] : defaultSource
      let timestamp =
        isReceived
        ? UInt32(buffer[8]) | UInt32(buffer[9]) << 8 | UInt32(buffer[10]) << 16
          | UInt32(buffer[11]) << 24 : time
      let count = Int(buffer[headerCount - 1])
      guard count <= Message.maxDataCount, buffer.count - 1 - headerCount == count else {
        return nil
      }
      return Message(
        pgn: pgn, priority: priority, source: source, destination: destination,
        data: Array(buffer[headerCount..<headerCount + count]), timestamp: timestamp)
    }
  }
}
