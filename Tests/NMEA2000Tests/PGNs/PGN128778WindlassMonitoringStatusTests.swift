// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128778 WindlassMonitoringStatus")
struct WindlassMonitoringStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128778`.
  static let vectors: [(WindlassMonitoringStatus, [UInt8])] = [
    // typical
    (
      WindlassMonitoringStatus(
        windlassID: 1, sequenceID: 8, totalMotorTime: 3600, controllerVoltage: 12.6,
        motorCurrent: 85, monitoringEvents: WindlassMonitoringEvents(rawValue: 0x05)),
      [0x08, 0x01, 0x05, 0x3f, 0x55, 0x3c, 0x00, 0xff]
    ),
    // other values
    (
      WindlassMonitoringStatus(
        windlassID: 2, sequenceID: 9, totalMotorTime: 60, controllerVoltage: 0.2,
        motorCurrent: 1, monitoringEvents: WindlassMonitoringEvents(rawValue: 0x06)),
      [0x09, 0x02, 0x06, 0x01, 0x01, 0x01, 0x00, 0xff]
    ),
    // not available
    (
      WindlassMonitoringStatus(
        windlassID: 0xff, sequenceID: nil, totalMotorTime: nil, controllerVoltage: nil,
        motorCurrent: nil, monitoringEvents: []),
      [0xff, 0xff, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      WindlassMonitoringStatus(windlassID: 1, sequenceID: 8, totalMotorTime: 3600),
      [0x08, 0x01, 0x00, 0xff, 0xff, 0x3c, 0x00, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: WindlassMonitoringStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: WindlassMonitoringStatus, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(WindlassMonitoringStatus.self, from: Self.vectors[0].1)
  }

  @Test func decodesOnlyDefinedMonitoringEventBits() throws {
    // Upstream's tN2kDD477::SetEvents keeps only the three defined bits.
    var bytes = Self.vectors[0].1
    bytes[2] = 0xff
    let decoded = try WindlassMonitoringStatus(Message(pgn: 128778, data: bytes))
    #expect(decoded.monitoringEvents.rawValue == 0x07)
  }
}
