// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127508 BatteryStatus")
struct BatteryStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127508`.
  static let vectors: [(BatteryStatus, [UInt8])] = [
    // typical
    (
      BatteryStatus(
        batteryInstance: 1, voltage: 12.85, current: -25.5, temperature: 298.15, sequenceID: 7),
      [0x01, 0x05, 0x05, 0x01, 0xff, 0x77, 0x74, 0x07]
    ),
    // not available
    (
      BatteryStatus(
        batteryInstance: 0xff, voltage: nil, current: nil, temperature: nil, sequenceID: nil),
      [0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      BatteryStatus(batteryInstance: 0, voltage: 13.2),
      [0x00, 0x28, 0x05, 0xff, 0x7f, 0xff, 0xff, 0x01]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: BatteryStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: BatteryStatus, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(BatteryStatus.self, from: Self.vectors[0].1)
  }
}
