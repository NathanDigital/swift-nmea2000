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
  public static func encode(_ message: Message) -> String {
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

  /// Decodes a sentence, or returns `nil` if it isn't a valid `$PCDIN`
  /// sentence. Hex digits may be in either case, and anything after the
  /// checksum, such as a line ending, is ignored.
  ///
  /// Ports `SeasmartToN2k`.
  public static func decode(_ sentence: String) -> Message? {
    var parser = Parser(text: Array(sentence.utf8))
    guard parser.skip("$PCDIN,"),
      let pgnHigh = parser.hex(bytes: 1), let pgnLow = parser.hex(bytes: 2), parser.skip(","),
      let timestamp = parser.hex(bytes: 4), parser.skip(","),
      let source = parser.hex(bytes: 1), parser.skip(",")
    else { return nil }
    let digitCount = parser.countUntilEnd()
    guard digitCount.isMultiple(of: 2), digitCount / 2 <= Message.maxDataCount else { return nil }
    var data: [UInt8] = []
    for _ in 0..<digitCount / 2 {
      guard let byte = parser.hex(bytes: 1) else { return nil }
      data.append(UInt8(byte))
    }
    guard parser.skip("*"), let expected = parser.hex(bytes: 1),
      expected == checksum(parser.text)
    else { return nil }
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

    /// Skips a literal, if it comes next.
    mutating func skip(_ literal: String) -> Bool {
      let bytes = Array(literal.utf8)
      guard text[index...].starts(with: bytes) else { return false }
      index += bytes.count
      return true
    }

    /// Reads `bytes` bytes written as twice as many hex digits
    /// (`readNHexByte`).
    mutating func hex(bytes: Int) -> UInt32? {
      let end = index + 2 * bytes
      guard end <= text.count,
        text[index..<end].allSatisfy({ Character(Unicode.Scalar($0)).isHexDigit })
      else { return nil }
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
