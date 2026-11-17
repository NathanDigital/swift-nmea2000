// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130310 OutsideEnvironmentalParameters")
struct OutsideEnvironmentalParametersTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130310`.
  static let vectors: [(OutsideEnvironmentalParameters, [UInt8])] = [
    // typical
    (
      OutsideEnvironmentalParameters(
        sequenceID: 1, waterTemperature: 288.15, outsideAirTemperature: 293.65,
        atmosphericPressure: 101325),
      [0x01, 0x8f, 0x70, 0xb5, 0x72, 0xf5, 0x03, 0xff]
    ),
    // not available
    (
      OutsideEnvironmentalParameters(
        sequenceID: nil, waterTemperature: nil, outsideAirTemperature: nil, atmosphericPressure: nil
      ),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      OutsideEnvironmentalParameters(sequenceID: 1, waterTemperature: 285.5),
      [0x01, 0x86, 0x6f, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: OutsideEnvironmentalParameters, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(OutsideEnvironmentalParameters.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(OutsideEnvironmentalParameters.self, from: Self.vectors[0].1)
  }
}
