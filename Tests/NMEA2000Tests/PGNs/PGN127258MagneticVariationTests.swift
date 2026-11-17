// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127258 MagneticVariation")
struct MagneticVariationTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127258`.
  static let vectors: [(MagneticVariation, [UInt8])] = [
    // typical
    (
      MagneticVariation(sequenceID: 6, source: .wmm2020, daysSince1970: 19000, variation: -0.05),
      [0x06, 0x08, 0x38, 0x4a, 0x0c, 0xfe, 0xff, 0xff]
    ),
    // not available
    (
      MagneticVariation(sequenceID: nil, source: .manual, daysSince1970: nil, variation: nil),
      [0xff, 0x00, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: MagneticVariation, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(MagneticVariation.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(MagneticVariation.self, from: Self.vectors[0].1)
  }
}
