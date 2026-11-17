// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130306 WindData")
struct WindDataTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130306`.
  static let vectors: [(WindData, [UInt8])] = [
    // typical
    (
      WindData(sequenceID: 1, windSpeed: 7.5, windAngle: 5.5, reference: .apparent),
      [0x01, 0xee, 0x02, 0xd8, 0xd6, 0x02, 0xff, 0xff]
    ),
    // true over water
    (
      WindData(sequenceID: 2, windSpeed: 12.25, windAngle: 0.25, reference: .trueWater),
      [0x02, 0xc9, 0x04, 0xc4, 0x09, 0x04, 0xff, 0xff]
    ),
    // not available
    (
      WindData(sequenceID: nil, windSpeed: nil, windAngle: nil, reference: .unavailable),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0x07, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: WindData, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: WindData, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(WindData.self, from: Self.vectors[0].1)
  }
}
