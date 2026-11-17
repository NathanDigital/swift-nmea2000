// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 59904 ISO Request")
struct ISORequestTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN59904`.
  static let vectors: [(ISORequest, [UInt8])] = [
    // typical
    (
      ISORequest(requestedPGN: 126996),
      [0x14, 0xf0, 0x01]
    ),
    // high bits
    (
      ISORequest(requestedPGN: 0xfedcba),
      [0xba, 0xdc, 0xfe]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ISORequest, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ISORequest, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func acceptsThreeToEightBytes() throws {
    for count in 3...8 {
      let data = [0x14, 0xf0, 0x01] + Array(repeating: UInt8(0xff), count: count - 3)
      #expect(try ISORequest(Message(pgn: 59904, data: data)).requestedPGN == 126996)
    }
  }

  @Test func rejectsOtherLengthsAsUpstreamDoes() {
    for count in [0, 1, 2, 9] {
      #expect(throws: MessageDecodingError.self, "\(count) bytes") {
        _ = try ISORequest(Message(pgn: 59904, data: Array(repeating: 0x14, count: count)))
      }
    }
  }
}
