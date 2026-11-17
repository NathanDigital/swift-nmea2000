// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129284 NavigationInfo")
struct NavigationInfoTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129284`.
  static let vectors: [(NavigationInfo, [UInt8])] = [
    // typical
    (
      NavigationInfo(
        sequenceID: 12, distanceToWaypoint: 1852.5, bearingReference: .magnetic,
        isPerpendicularCrossed: true, isArrivalCircleEntered: false, calculationType: .rhumbLine,
        etaTime: 45000.5, etaDate: 19001, bearingOriginToDestination: 0.5,
        bearingPositionToDestination: 0.6, originWaypointNumber: 100,
        destinationWaypointNumber: 101,
        destinationLatitude: 60.15, destinationLongitude: 24.95, waypointClosingVelocity: -1.25),
      [
        0x0c, 0xa2, 0xd3, 0x02, 0x00, 0x45, 0x08, 0x88, 0xd2, 0x1a, 0x39, 0x4a, 0x88, 0x13, 0x70,
        0x17, 0x64, 0x00, 0x00, 0x00, 0x65, 0x00, 0x00, 0x00, 0x60, 0x29, 0xda, 0x23, 0x60, 0x11,
        0xdf, 0x0e, 0x83, 0xff,
      ]
    ),
    // not available
    (
      NavigationInfo(
        sequenceID: nil, distanceToWaypoint: nil, bearingReference: .true,
        isPerpendicularCrossed: false,
        isArrivalCircleEntered: true, calculationType: .greatCircle, etaTime: nil, etaDate: nil,
        bearingOriginToDestination: nil, bearingPositionToDestination: nil,
        originWaypointNumber: nil,
        destinationWaypointNumber: nil, destinationLatitude: nil, destinationLongitude: nil,
        waypointClosingVelocity: nil),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0x10, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff,
        0xff, 0x7f, 0xff, 0x7f,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: NavigationInfo, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(NavigationInfo.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(NavigationInfo.self, from: Self.vectors[0].1)
  }

  @Test func decodesBearingReferenceFromBitZeroOnly() throws {
    var bytes = Self.vectors[0].1
    bytes[5] = 0x03  // HeadingReference.unavailable, as upstream would send it.
    #expect(try NavigationInfo(Message(pgn: 129284, data: bytes)).bearingReference == .magnetic)
  }
}
