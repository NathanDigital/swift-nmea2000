// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127489 EngineParametersDynamic")
struct EngineParametersDynamicTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127489`.
  static let vectors: [(EngineParametersDynamic, [UInt8])] = [
    // typical
    (
      EngineParametersDynamic(
        instance: 1, oilPressure: 350000, oilTemperature: 363.15, coolantTemperature: 358.15,
        alternatorVoltage: 14.2, fuelRate: -12.5, engineHours: 3_600_000, coolantPressure: 120000,
        fuelPressure: 300000, load: 85, torque: -5,
        status1: EngineDiscreteStatus1(rawValue: 0x8421),
        status2: EngineDiscreteStatus2(rawValue: 0x00a5)),
      [
        0x01, 0xac, 0x0d, 0x2f, 0x0e, 0xe7, 0x8b, 0x8c, 0x05, 0x83, 0xff, 0x80, 0xee, 0x36, 0x00,
        0xb0, 0x04, 0x2c, 0x01, 0xff, 0x21, 0x84, 0xa5, 0x00, 0x55, 0xfb,
      ]
    ),
    // not available
    (
      EngineParametersDynamic(
        instance: 0xff, oilPressure: nil, oilTemperature: nil, coolantTemperature: nil,
        alternatorVoltage: nil, fuelRate: nil, engineHours: nil, coolantPressure: nil,
        fuelPressure: nil, load: nil, torque: nil, status1: [], status2: []),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x7f, 0x7f,
      ]
    ),
    // defaults
    (
      EngineParametersDynamic(
        instance: 0, oilPressure: 300000, oilTemperature: 360, coolantTemperature: 350,
        alternatorVoltage: 13.8, fuelRate: 10, engineHours: 7200),
      [
        0x00, 0xb8, 0x0b, 0x10, 0x0e, 0xb8, 0x88, 0x64, 0x05, 0x64, 0x00, 0x20, 0x1c, 0x00, 0x00,
        0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x7f, 0x7f,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: EngineParametersDynamic, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: EngineParametersDynamic, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(EngineParametersDynamic.self, from: Self.vectors[0].1)
  }

  @Test func decodesOnlyLowByteOfStatus2() throws {
    // Upstream assigns through tN2kDD223::operator=, which keeps the low byte only.
    var bytes = Self.vectors[0].1
    bytes[22] = 0xff  // Discrete status 2.
    bytes[23] = 0xff
    let decoded = try EngineParametersDynamic(Message(pgn: 127489, data: bytes))
    #expect(decoded.status2.rawValue == 0x00ff)
  }
}
