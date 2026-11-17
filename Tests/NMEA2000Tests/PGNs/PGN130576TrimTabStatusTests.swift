// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130576 TrimTabStatus")
struct TrimTabStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130576`.
  static let vectors: [(TrimTabStatus, [UInt8])] = [
    // typical
    (
      TrimTabStatus(portTrimTab: 25, starboardTrimTab: -10),
      [0x19, 0xf6, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      TrimTabStatus(portTrimTab: nil, starboardTrimTab: nil),
      [0x7f, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: TrimTabStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: TrimTabStatus, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(TrimTabStatus.self, from: Self.vectors[0].1)
  }
}
