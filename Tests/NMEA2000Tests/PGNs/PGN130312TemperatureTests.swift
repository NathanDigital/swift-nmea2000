// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130312 Temperature")
struct TemperatureTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130312`.
  static let vectors: [(Temperature, [UInt8])] = [
    // typical
    (
      Temperature(
        instance: 3, source: .freezer, sequenceID: 1, actualTemperature: 255.15,
        setTemperature: 253.15),
      [0x01, 0x03, 0x0d, 0xab, 0x63, 0xe3, 0x62, 0xff]
    ),
    // unknown source
    (
      Temperature(
        instance: 0xfe, source: TemperatureSource(rawValue: 0xc8), sequenceID: 2,
        actualTemperature: 600, setTemperature: nil),
      [0x02, 0xfe, 0xc8, 0x60, 0xea, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      Temperature(
        instance: 0xff, source: TemperatureSource(rawValue: 0xff), sequenceID: nil,
        actualTemperature: nil, setTemperature: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      Temperature(instance: 0, source: .engineRoom, sequenceID: 1, actualTemperature: 320),
      [0x01, 0x00, 0x03, 0x00, 0x7d, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Temperature, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: Temperature, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Temperature.self, from: Self.vectors[0].1)
  }
}
