// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128275 DistanceLog")
struct DistanceLogTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128275`.
  static let vectors: [(DistanceLog, [UInt8])] = [
    // typical
    (
      DistanceLog(daysSince1970: 19000, secondsSinceMidnight: 3600.25, log: 123456, tripLog: 789),
      [0x38, 0x4a, 0xc4, 0x5a, 0x25, 0x02, 0x40, 0xe2, 0x01, 0x00, 0x15, 0x03, 0x00, 0x00]
    ),
    // not available
    (
      DistanceLog(daysSince1970: nil, secondsSinceMidnight: nil, log: nil, tripLog: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: DistanceLog, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: DistanceLog, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(DistanceLog.self, from: Self.vectors[0].1)
  }
}
