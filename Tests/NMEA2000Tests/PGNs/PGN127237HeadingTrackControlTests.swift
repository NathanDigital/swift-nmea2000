// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127237 HeadingTrackControl")
struct HeadingTrackControlTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127237`.
  static let vectors: [(HeadingTrackControl, [UInt8])] = [
    // typical
    (
      HeadingTrackControl(
        rudderLimitExceeded: .on, offHeadingLimitExceeded: .off, offTrackLimitExceeded: .error,
        override: .unavailable, steeringMode: .trackControl, turnMode: .radiusControlled,
        headingReference: .magnetic,
        commandedRudderDirection: .moveToPort, commandedRudderAngle: -0.1, headingToSteer: 1.2,
        track: 1.25,
        rudderLimit: 0.6, offHeadingLimit: 0.2, radiusOfTurnOrder: -250, rateOfTurnOrder: -0.05,
        offTrackLimit: -40, vesselHeading: 1.3),
      [
        0xe1, 0x55, 0x5f, 0x18, 0xfc, 0xe0, 0x2e, 0xd4, 0x30, 0x70, 0x17, 0xd0, 0x07, 0x06, 0xff,
        0xc0, 0xf9, 0xd8, 0xff, 0xc8, 0x32,
      ]
    ),
    // unknown values
    (
      HeadingTrackControl(
        rudderLimitExceeded: .off, offHeadingLimitExceeded: .unavailable,
        offTrackLimitExceeded: .on,
        override: .error, steeringMode: SteeringMode(rawValue: 6), turnMode: .unavailable,
        headingReference: .error,
        commandedRudderDirection: RudderDirectionOrder(rawValue: 6), commandedRudderAngle: 0.1,
        headingToSteer: 0, track: 0,
        rudderLimit: 0, offHeadingLimit: 0, radiusOfTurnOrder: 250, rateOfTurnOrder: 0.05,
        offTrackLimit: 40, vesselHeading: 0),
      [
        0x9c, 0xbe, 0xdf, 0xe8, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfa, 0x00,
        0x40, 0x06, 0x28, 0x00, 0x00, 0x00,
      ]
    ),
    // not available
    (
      HeadingTrackControl(
        rudderLimitExceeded: .unavailable, offHeadingLimitExceeded: .unavailable,
        offTrackLimitExceeded: .unavailable,
        override: .unavailable, steeringMode: .unavailable, turnMode: .unavailable,
        headingReference: .unavailable,
        commandedRudderDirection: .unavailable, commandedRudderAngle: nil, headingToSteer: nil,
        track: nil,
        rudderLimit: nil, offHeadingLimit: nil, radiusOfTurnOrder: nil, rateOfTurnOrder: nil,
        offTrackLimit: nil, vesselHeading: nil),
      [
        0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f,
        0xff, 0x7f, 0xff, 0x7f, 0xff, 0xff,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: HeadingTrackControl, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(HeadingTrackControl.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(HeadingTrackControl.self, from: Self.vectors[0].1)
  }
}
