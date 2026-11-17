// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127488 EngineParametersRapid")
struct EngineParametersRapidTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127488`.
  static let vectors: [(EngineParametersRapid, [UInt8])] = [
    // typical
    (
      EngineParametersRapid(instance: 1, speed: 2450.25, boostPressure: 150000, tiltTrim: -12),
      [0x01, 0x49, 0x26, 0xdc, 0x05, 0xf4, 0xff, 0xff]
    ),
    // not available
    (
      EngineParametersRapid(instance: 0xff, speed: nil, boostPressure: nil, tiltTrim: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
    // defaults
    (
      EngineParametersRapid(instance: 0, speed: 800),
      [0x00, 0x80, 0x0c, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: EngineParametersRapid, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(EngineParametersRapid.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(EngineParametersRapid.self, from: Self.vectors[0].1)
  }
}
