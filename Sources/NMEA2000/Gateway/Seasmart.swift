// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The SeaSmart.Net `$PCDIN` sentence, which carries an NMEA 2000 message as
/// NMEA 0183 text: the PGN, a time stamp and the source in hex, then the
/// payload in hex and an NMEA 0183 checksum.
///
/// `$PCDIN,01F112,01020304,01,010203ABCDEF10FF*26`
///
/// The sentence doesn't carry the priority or destination; decoded messages
/// get ``Message``'s defaults.
///
/// Ports `N2kToSeasmart` and `SeasmartToN2k`.
public enum Seasmart {
  /// Encodes a message as a sentence, without a line ending. The message's
  /// ``Message/timestamp`` is the time stamp.
  ///
  /// Ports `N2kToSeasmart`.
  ///
  /// - Throws: ``GatewayError/payloadTooLong(count:)`` for a payload longer
  ///   than ``Message/maxDataCount``, which upstream's message can't hold
  ///   and ``decode(_:)`` rejects.
  public static func encode(_ message: Message) throws(GatewayError) -> String {
    guard message.data.count <= Message.maxDataCount else {
      throw .payloadTooLong(count: message.data.count)
    }
    var sentence = "$PCDIN,"
    sentence += hex(UInt8(truncatingIfNeeded: message.pgn >> 16))
    sentence += hex(UInt8(truncatingIfNeeded: message.pgn >> 8))
    sentence += hex(UInt8(truncatingIfNeeded: message.pgn)) + ","
    for shift in stride(from: 24, through: 0, by: -8) {
      sentence += hex(UInt8(truncatingIfNeeded: message.timestamp >> shift))
    }
    sentence += "," + hex(message.source) + ","
    for byte in message.data { sentence += hex(byte) }
    return sentence + "*" + hex(checksum(Array(sentence.utf8)))
  }

  /// Decodes a sentence. Hex digits may be in either case, and anything
  /// after the checksum, such as a line ending, is ignored.
  ///
  /// Ports `SeasmartToN2k`.
  ///
  /// - Throws: ``GatewayError/malformedSentence(offset:)`` where the sentence
  ///   isn't a `$PCDIN` sentence, ``GatewayError/payloadTooLong(count:)``,
  ///   or ``GatewayError/checksumMismatch(expected:actual:)``.
  public static func decode(_ sentence: String) throws(GatewayError) -> Message {
    var parser = Parser(text: Array(sentence.utf8))
    try parser.expect("$PCDIN,")
    let pgnHigh = try parser.hex(bytes: 1)
    let pgnLow = try parser.hex(bytes: 2)
    try parser.expect(",")
    let timestamp = try parser.hex(bytes: 4)
    try parser.expect(",")
    let source = try parser.hex(bytes: 1)
    try parser.expect(",")
    let digitCount = parser.countUntilEnd()
    guard digitCount.isMultiple(of: 2) else {
      throw .malformedSentence(offset: parser.index + digitCount)
    }
    guard digitCount / 2 <= Message.maxDataCount else {
      throw .payloadTooLong(count: digitCount / 2)
    }
    var data: [UInt8] = []
    for _ in 0..<digitCount / 2 {
      data.append(UInt8(try parser.hex(bytes: 1)))
    }
    try parser.expect("*")
    let expected = UInt8(try parser.hex(bytes: 1))
    let actual = checksum(parser.text)
    guard expected == actual else { throw .checksumMismatch(expected: expected, actual: actual) }
    return Message(
      pgn: pgnHigh << 16 + pgnLow, source: UInt8(source), data: data, timestamp: timestamp)
  }

  /// The NMEA 0183 checksum: the XOR of the bytes between `$` and `*`.
  static func checksum(_ text: [UInt8]) -> UInt8 {
    text.dropFirst().prefix { $0 != UInt8(ascii: "*") && $0 != 0 }.reduce(0, ^)
  }

  private static func hex(_ byte: UInt8) -> String {
    let digits = Array("0123456789ABCDEF")
    return String([digits[Int(byte >> 4)], digits[Int(byte & 0xf)]])
  }

  /// Reads a sentence left to right, as upstream's pointer does.
  private struct Parser {
    let text: [UInt8]
    var index = 0

    /// Skips a literal, which must come next.
    mutating func expect(_ literal: String) throws(GatewayError) {
      let bytes = Array(literal.utf8)
      guard text[index...].starts(with: bytes) else { throw .malformedSentence(offset: index) }
      index += bytes.count
    }

    /// Reads `bytes` bytes written as twice as many hex digits
    /// (`readNHexByte`).
    mutating func hex(bytes: Int) throws(GatewayError) -> UInt32 {
      let end = index + 2 * bytes
      guard end <= text.count,
        text[index..<end].allSatisfy({ Character(Unicode.Scalar($0)).isHexDigit })
      else { throw .malformedSentence(offset: index) }
      let value = text[index..<end].reduce(UInt32(0)) {
        $0 << 4 | UInt32(Character(Unicode.Scalar($1)).hexDigitValue ?? 0)
      }
      index = end
      return value
    }

    /// How many characters come before `*` or the end.
    func countUntilEnd() -> Int {
      text[index...].prefix { $0 != UInt8(ascii: "*") && $0 != 0 }.count
    }
  }
}
