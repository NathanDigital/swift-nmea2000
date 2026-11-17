// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 126992 SystemTime")
struct SystemTimeTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN126992`.
  static let vectors: [(SystemTime, [UInt8])] = [
    // typical
    (
      SystemTime(sequenceID: 1, daysSince1970: 20000, secondsSinceMidnight: 43200.5, source: .gps),
      [0x01, 0xf0, 0x20, 0x4e, 0x88, 0xdf, 0xbf, 0x19]
    ),
    // not available
    (
      SystemTime(
        sequenceID: nil, daysSince1970: nil, secondsSinceMidnight: nil, source: .localCrystalClock),
      [0xff, 0xf5, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // unknown time source
    (
      SystemTime(
        sequenceID: 1, daysSince1970: 20000, secondsSinceMidnight: 43200.5,
        source: TimeSource(rawValue: 10)),
      [0x01, 0xfa, 0x20, 0x4e, 0x88, 0xdf, 0xbf, 0x19]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: SystemTime, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(SystemTime.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(SystemTime.self, from: Self.vectors[0].1)
  }
}
