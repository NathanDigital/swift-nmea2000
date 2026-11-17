// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127233 ManOverboardNotification")
struct ManOverboardNotificationTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127233`.
  static let vectors: [(ManOverboardNotification, [UInt8])] = [
    // typical
    (
      ManOverboardNotification(
        sequenceID: 1, emitterID: 0x1234_5678, status: .manualButtonActivation,
        activationTime: 43200.5,
        positionSource: .reportedByEmitter, positionDate: 19000, positionTime: 43210.25,
        latitude: -33.8688,
        longitude: -151.2093, courseReference: .magnetic, courseOverGround: 2.5,
        speedOverGround: 1.25,
        mmsi: 230_123_456, emitterBatteryStatus: .low),
      [
        0x01, 0x78, 0x56, 0x34, 0x12, 0xf9, 0x88, 0xdf, 0xbf, 0x19, 0xf9, 0x38, 0x4a, 0x64, 0x5c,
        0xc1, 0x19, 0x00, 0x08, 0xd0, 0xeb, 0xb8, 0x4a, 0xdf, 0xa5, 0xfd, 0xa8, 0x61, 0x7d, 0x00,
        0xc0, 0x67, 0xb7, 0x0d, 0xf9,
      ]
    ),
    // unknown values
    (
      ManOverboardNotification(
        sequenceID: 2, emitterID: 7, status: MOBStatus(rawValue: 5), activationTime: 0,
        positionSource: MOBPositionSource(rawValue: 6), positionDate: 0, positionTime: 0,
        latitude: 0,
        longitude: 0, courseReference: .unavailable, courseOverGround: 0, speedOverGround: 0,
        mmsi: 0, emitterBatteryStatus: MOBEmitterBatteryStatus(rawValue: 4)),
      [
        0x02, 0x07, 0x00, 0x00, 0x00, 0xfd, 0x00, 0x00, 0x00, 0x00, 0xfe, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xfc,
      ]
    ),
    // not available
    (
      ManOverboardNotification(
        sequenceID: nil, emitterID: nil, status: .notActive, activationTime: nil,
        positionSource: .estimatedByVessel, positionDate: nil, positionTime: nil, latitude: nil,
        longitude: nil, courseReference: .true, courseOverGround: nil, speedOverGround: nil,
        mmsi: nil, emitterBatteryStatus: .good),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0xfb, 0xff, 0xff, 0xff, 0xff, 0xf8, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xfc, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xf8,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ManOverboardNotification, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(ManOverboardNotification.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ManOverboardNotification.self, from: Self.vectors[0].1)
  }
}
