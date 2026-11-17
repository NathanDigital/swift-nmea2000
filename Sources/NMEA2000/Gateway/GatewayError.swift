// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// An error that occurs when a gateway codec can't encode a message or
/// decode a sentence.
public enum GatewayError: Error, Hashable, Sendable {
  /// The message has no PGN, which upstream refuses to write.
  case missingPGN

  /// The message has no payload, which upstream refuses to write.
  case emptyPayload

  /// The payload is longer than ``Message/maxDataCount`` bytes.
  case payloadTooLong(count: Int)

  /// The sentence doesn't follow the format, starting at this byte offset.
  case malformedSentence(offset: Int)

  /// The sentence's checksum doesn't match its contents.
  case checksumMismatch(expected: UInt8, actual: UInt8)

  /// Checks what every gateway format needs of a message to encode.
  static func check(_ message: Message) throws(GatewayError) {
    guard message.pgn != 0 else { throw .missingPGN }
    guard message.data.count <= Message.maxDataCount else {
      throw .payloadTooLong(count: message.data.count)
    }
  }
}
