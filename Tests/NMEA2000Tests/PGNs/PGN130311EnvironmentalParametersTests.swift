// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130311 EnvironmentalParameters")
struct EnvironmentalParametersTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130311`.
  static let vectors: [(EnvironmentalParameters, [UInt8])] = [
    // typical
    (
      EnvironmentalParameters(
        sequenceID: 1, temperatureSource: .shaftSeal, temperature: 310.5, humiditySource: .outside,
        humidity: 65.5, atmosphericPressure: 100800),
      [0x01, 0x4f, 0x4a, 0x79, 0xf7, 0x3f, 0xf0, 0x03]
    ),
    // high temperature source code
    (
      EnvironmentalParameters(
        sequenceID: 2, temperatureSource: TemperatureSource(rawValue: 0x2a), temperature: 250,
        humiditySource: .inside,
        humidity: -1.0, atmosphericPressure: 99000),
      [0x02, 0x2a, 0xa8, 0x61, 0x06, 0xff, 0xde, 0x03]
    ),
    // not available
    (
      EnvironmentalParameters(
        sequenceID: nil, temperatureSource: .sea, temperature: nil, humiditySource: .undefined,
        humidity: nil, atmosphericPressure: nil),
      [0xff, 0xc0, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
    // defaults
    (
      EnvironmentalParameters(sequenceID: 1, temperatureSource: .mainCabin, temperature: 294.15),
      [0x01, 0xc4, 0xe7, 0x72, 0xff, 0x7f, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: EnvironmentalParameters, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: EnvironmentalParameters, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(EnvironmentalParameters.self, from: Self.vectors[0].1)
  }

  @Test(
    "Decodes the two-bit humidity source",
    arguments: [
      (0, .inside), (1, .outside), (2, HumiditySource(rawValue: 2)), (3, .undefined),
    ] as [(UInt8, HumiditySource)])
  func decodesHumiditySource(code: UInt8, expected: HumiditySource) throws {
    // Deliberate divergence: upstream decodes code 3 as a raw value that doesn't equal
    // its own N2khs_Undef constant.
    var bytes = Self.vectors[0].1
    bytes[1] = bytes[1] & 0x3f | code << 6
    #expect(
      try EnvironmentalParameters(Message(pgn: 130311, data: bytes)).humiditySource == expected)
  }
}
