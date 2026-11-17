// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127245 Rudder")
struct RudderTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127245`.
  static let vectors: [(Rudder, [UInt8])] = [
    // typical
    (
      Rudder(position: -0.1, instance: 2, directionOrder: .moveToStarboard, angleOrder: 0.25),
      [0x02, 0xf9, 0xc4, 0x09, 0x18, 0xfc, 0xff, 0xff]
    ),
    // unknown direction
    (
      Rudder(
        position: 0.1, instance: 0, directionOrder: RudderDirectionOrder(rawValue: 6),
        angleOrder: -0.25),
      [0x00, 0xfe, 0x3c, 0xf6, 0xe8, 0x03, 0xff, 0xff]
    ),
    // not available
    (
      Rudder(position: nil, instance: 0xff, directionOrder: .unavailable, angleOrder: nil),
      [0xff, 0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Rudder, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(Rudder.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Rudder.self, from: Self.vectors[0].1)
  }
}
