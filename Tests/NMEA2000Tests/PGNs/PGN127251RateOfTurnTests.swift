// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127251 RateOfTurn")
struct RateOfTurnTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127251`.
  static let vectors: [(RateOfTurn, [UInt8])] = [
    // typical
    (
      RateOfTurn(sequenceID: 3, rate: -0.02),
      [0x03, 0x00, 0x3c, 0xf6, 0xff, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      RateOfTurn(sequenceID: nil, rate: nil),
      [0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: RateOfTurn, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(RateOfTurn.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(RateOfTurn.self, from: Self.vectors[0].1)
  }
}
