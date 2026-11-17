// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127510 ChargerConfigurationStatus")
struct ChargerConfigurationStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127510`.
  static let vectors: [(ChargerConfigurationStatus, [UInt8])] = [
    // typical
    (
      ChargerConfigurationStatus(
        chargerInstance: 1, batteryInstance: 2, enabled: .on, chargeCurrentLimit: 80,
        chargingAlgorithm: .twoStage, chargerMode: .primary, batteryTemperature: .hot,
        equalizationEnabled: .error,
        overchargeEnabled: .on, equalizationTime: 7200),
      [0x01, 0x02, 0x01, 0x50, 0x12, 0x62, 0x78, 0x00]
    ),
    // high values
    (
      ChargerConfigurationStatus(
        chargerInstance: 3, batteryInstance: 4, enabled: .unavailable, chargeCurrentLimit: 252,
        chargingAlgorithm: .error, chargerMode: .echo, batteryTemperature: .error,
        equalizationEnabled: .unavailable,
        overchargeEnabled: .error, equalizationTime: 0),
      [0x03, 0x04, 0x03, 0xfc, 0x3e, 0xbe, 0x00, 0x00]
    ),
    // not available
    (
      ChargerConfigurationStatus(
        chargerInstance: 0xff, batteryInstance: 0xff, enabled: .unavailable,
        chargeCurrentLimit: nil,
        chargingAlgorithm: .unavailable, chargerMode: .unavailable,
        batteryTemperature: .unavailable, equalizationEnabled: .unavailable,
        overchargeEnabled: .unavailable, equalizationTime: nil),
      [0xff, 0xff, 0x03, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      ChargerConfigurationStatus(chargerInstance: 0, batteryInstance: 1),
      [0x00, 0x01, 0x01, 0xff, 0x03, 0x0f, 0x00, 0x00]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ChargerConfigurationStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ChargerConfigurationStatus, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ChargerConfigurationStatus.self, from: Self.vectors[0].1)
  }

  @Test func sendsEqualizationTimeInMinutes() {
    // Deliberate divergence: upstream documents seconds but sends the number unscaled,
    // while the field is in minutes.
    let message = ChargerConfigurationStatus(
      chargerInstance: 0, batteryInstance: 0, equalizationTime: 7200
    ).makeMessage()
    #expect(message.data.suffix(2) == [0x78, 0x00])
  }

  @Test(
    "Decodes all four bits of the battery temperature",
    arguments: [
      (UInt8(0x02), BatteryTemperatureEstimate.hot), (0x0e, .error), (0x0f, .unavailable),
    ])
  func decodesBatteryTemperature(bits: UInt8, expected: BatteryTemperatureEstimate) throws {
    // Deliberate divergence: upstream masks this field with 0x04.
    var bytes = Self.vectors[0].1
    bytes[5] = bytes[5] & 0xf0 | bits
    #expect(
      try ChargerConfigurationStatus(Message(pgn: 127510, data: bytes)).batteryTemperature
        == expected)
  }
}
