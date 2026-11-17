// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129033 TimeAndDate")
struct TimeAndDateTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129033`.
  static let vectors: [(TimeAndDate, [UInt8])] = [
    // typical
    (
      TimeAndDate(daysSince1970: 19000, secondsSinceMidnight: 3600, localOffset: -120),
      [0x38, 0x4a, 0x00, 0x51, 0x25, 0x02, 0x88, 0xff]
    ),
    // not available
    (
      TimeAndDate(daysSince1970: nil, secondsSinceMidnight: nil, localOffset: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: TimeAndDate, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(TimeAndDate.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(TimeAndDate.self, from: Self.vectors[0].1)
  }
}
