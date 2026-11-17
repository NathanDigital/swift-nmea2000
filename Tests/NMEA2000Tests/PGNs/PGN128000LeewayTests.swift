// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128000 Leeway")
struct LeewayTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128000`.
  static let vectors: [(Leeway, [UInt8])] = [
    // typical
    (
      Leeway(sequenceID: 3, leeway: -0.05),
      [0x03, 0x0c, 0xfe, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      Leeway(sequenceID: nil, leeway: nil),
      [0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Leeway, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 4)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: Leeway, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Leeway.self, from: Self.vectors[0].1)
  }
}
