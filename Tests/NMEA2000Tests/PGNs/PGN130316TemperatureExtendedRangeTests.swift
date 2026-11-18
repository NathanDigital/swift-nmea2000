// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130316 TemperatureExtendedRange")
struct TemperatureExtendedRangeTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130316`.
  static let vectors: [(TemperatureExtendedRange, [UInt8])] = [
    // typical
    (
      TemperatureExtendedRange(
        instance: 4, source: .exhaustGas, sequenceID: 1, actualTemperature: 850.125,
        setTemperature: 900.5),
      [0x01, 0x04, 0x0e, 0xcd, 0xf8, 0x0c, 0x2d, 0x23]
    ),
    // high values
    (
      TemperatureExtendedRange(
        instance: 0xfe, source: TemperatureSource(rawValue: 0x80), sequenceID: 2,
        actualTemperature: 16000, setTemperature: 6000),
      [0x02, 0xfe, 0x80, 0x00, 0x24, 0xf4, 0x60, 0xea]
    ),
    // not available
    (
      TemperatureExtendedRange(
        instance: 0xff, source: TemperatureSource(rawValue: 0xff), sequenceID: nil,
        actualTemperature: nil, setTemperature: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      TemperatureExtendedRange(
        instance: 0, source: .outside, sequenceID: 1, actualTemperature: 278.15),
      [0x01, 0x00, 0x01, 0x86, 0x3e, 0x04, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: TemperatureExtendedRange, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: TemperatureExtendedRange, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(TemperatureExtendedRange.self, from: Self.vectors[0].1)
  }
}
