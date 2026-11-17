// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130577 DirectionData")
struct DirectionDataTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130577`.
  static let vectors: [(DirectionData, [UInt8])] = [
    // typical
    (
      DirectionData(
        dataMode: .estimated, courseReference: .true, sequenceID: 16, courseOverGround: 1.1,
        speedOverGround: 2.2, heading: 1.3, speedThroughWater: 2.1, set: 0.4, drift: 0.3),
      [0xc2, 0x10, 0xf8, 0x2a, 0xdc, 0x00, 0xc8, 0x32, 0xd2, 0x00, 0xa0, 0x0f, 0x1e, 0x00]
    ),
    // not available
    (
      DirectionData(
        dataMode: .unavailable, courseReference: .unavailable, sequenceID: nil,
        courseOverGround: nil,
        speedOverGround: nil, heading: nil, speedThroughWater: nil, set: nil, drift: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: DirectionData, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(DirectionData.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(DirectionData.self, from: Self.vectors[0].1)
  }
}
