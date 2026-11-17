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
        etaDaysSince1970: 19001, etaSecondsSinceMidnight: 45000.5, bearingOriginToDestination: 0.5,
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
        isArrivalCircleEntered: true, calculationType: .greatCircle, etaDaysSince1970: nil,
        etaSecondsSinceMidnight: nil,
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
    // bearing reference unavailable
    (
      NavigationInfo(
        sequenceID: 12, distanceToWaypoint: 1852.5, bearingReference: .unavailable,
        isPerpendicularCrossed: false, isArrivalCircleEntered: false, calculationType: .greatCircle,
        etaDaysSince1970: nil, etaSecondsSinceMidnight: nil, bearingOriginToDestination: 0.5,
        bearingPositionToDestination: 0.6,
        originWaypointNumber: 100, destinationWaypointNumber: 101, destinationLatitude: 60.15,
        destinationLongitude: 24.95, waypointClosingVelocity: nil),
      [
        0x0c, 0xa2, 0xd3, 0x02, 0x00, 0x03, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x88, 0x13, 0x70,
        0x17, 0x64, 0x00, 0x00, 0x00, 0x65, 0x00, 0x00, 0x00, 0x60, 0x29, 0xda, 0x23, 0x60, 0x11,
        0xdf, 0x0e, 0xff, 0x7f,
      ]
    ),
    // bearing reference error
    (
      NavigationInfo(
        sequenceID: 12, distanceToWaypoint: 1852.5, bearingReference: .error,
        isPerpendicularCrossed: true, isArrivalCircleEntered: true, calculationType: .rhumbLine,
        etaDaysSince1970: nil, etaSecondsSinceMidnight: nil, bearingOriginToDestination: 0.5,
        bearingPositionToDestination: 0.6,
        originWaypointNumber: 100, destinationWaypointNumber: 101, destinationLatitude: 60.15,
        destinationLongitude: 24.95, waypointClosingVelocity: nil),
      [
        0x0c, 0xa2, 0xd3, 0x02, 0x00, 0x56, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x88, 0x13, 0x70,
        0x17, 0x64, 0x00, 0x00, 0x00, 0x65, 0x00, 0x00, 0x00, 0x60, 0x29, 0xda, 0x23, 0x60, 0x11,
        0xdf, 0x0e, 0xff, 0x7f,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: NavigationInfo, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: NavigationInfo, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(NavigationInfo.self, from: Self.vectors[0].1)
  }

  @Test(
    "Decodes both bits of the bearing reference",
    arguments: [
      (UInt8(0x00), HeadingReference.true),
      (0x01, .magnetic),
      (0x02, .error),
      (0x03, .unavailable),
    ])
  func decodesBearingReference(bits: UInt8, expected: HeadingReference) throws {
    // Deliberate divergence: upstream decodes only bit 0, reading error and unavailable
    // as magnetic.
    var bytes = Self.vectors[0].1
    bytes[5] = bytes[5] & ~0x03 | bits
    #expect(try NavigationInfo(Message(pgn: 129284, data: bytes)).bearingReference == expected)
  }

  @Test(
    "Decodes the two-bit flags and calculation type",
    arguments: [
      (UInt8(0b00), Bool?.some(false), DistanceCalculationType.greatCircle),
      (0b01, true, .rhumbLine),
      (0b10, nil, DistanceCalculationType(rawValue: 2)),
      (0b11, nil, DistanceCalculationType(rawValue: 3)),
    ])
  func decodesTwoBitFields(
    bits: UInt8, flag: Bool?, calculationType: DistanceCalculationType
  ) throws {
    // Deliberate divergence: upstream decodes only the low bit of each, and
    // reads error and not available as true and rhumb line.
    var bytes = Self.vectors[0].1
    bytes[5] = bytes[5] & 0x03 | bits << 2 | bits << 4 | bits << 6
    let decoded = try NavigationInfo(Message(pgn: 129284, data: bytes))
    #expect(decoded.isPerpendicularCrossed == flag)
    #expect(decoded.isArrivalCircleEntered == flag)
    #expect(decoded.calculationType == calculationType)
    // Error is sent back as not available; everything else round-trips.
    let resent = bits == 0b10 ? bytes[5] & 0x03 | 0b11_11_00 | bits << 6 : bytes[5]
    #expect(decoded.makeMessage().data[5] == resent)
  }
}
