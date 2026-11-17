// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127513 BatteryConfigurationStatus")
struct BatteryConfigurationStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127513`.
  static let vectors: [(BatteryConfigurationStatus, [UInt8])] = [
    // typical
    (
      BatteryConfigurationStatus(
        batteryInstance: 1, type: .agm, supportsEqualization: .yes, nominalVoltage: .volts12,
        chemistry: .leadAcid,
        capacity: 720000, temperatureCoefficient: -2, peukertExponent: 1.25,
        chargeEfficiencyFactor: 95),
      [0x01, 0xd2, 0x01, 0xc8, 0x00, 0xfe, 0x7d, 0x5f]
    ),
    // large capacity and high values
    (
      BatteryConfigurationStatus(
        batteryInstance: 2, type: BatteryType(rawValue: 9), supportsEqualization: .unavailable,
        nominalVoltage: .volts48, chemistry: .nickelMetalHydride,
        capacity: 144_000_000, temperatureCoefficient: 3, peukertExponent: 1.504,
        chargeEfficiencyFactor: -10),
      [0x02, 0xf9, 0x46, 0x40, 0x9c, 0x03, 0xff, 0xf6]
    ),
    // not available
    (
      BatteryConfigurationStatus(
        batteryInstance: 0xff, type: .flooded, supportsEqualization: .no, nominalVoltage: .volts6,
        chemistry: .leadAcid,
        capacity: nil, temperatureCoefficient: nil, peukertExponent: nil,
        chargeEfficiencyFactor: nil),
      [0xff, 0xc0, 0x00, 0xff, 0xff, 0x7f, 0xff, 0x7f]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: BatteryConfigurationStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(BatteryConfigurationStatus.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(BatteryConfigurationStatus.self, from: Self.vectors[0].1)
  }

  @Test func decodesCapacityAsUnsigned() throws {
    // Deliberate divergence: upstream reads this unsigned field as signed.
    let decoded = try BatteryConfigurationStatus(Message(pgn: 127513, data: Self.vectors[1].1))
    #expect(decoded.capacity == 144_000_000)
  }

  @Test func decodesMissingPeukertExponentAsNil() throws {
    // Deliberate divergence: upstream adds 1 to its not-available sentinel.
    let decoded = try BatteryConfigurationStatus(Message(pgn: 127513, data: Self.vectors[2].1))
    #expect(decoded.peukertExponent == nil)
  }
}
