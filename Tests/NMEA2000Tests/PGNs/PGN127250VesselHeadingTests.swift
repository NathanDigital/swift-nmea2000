// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127250 VesselHeading")
struct VesselHeadingTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127250`.
  static let vectors: [(VesselHeading, [UInt8])] = [
    // typical
    (
      VesselHeading(
        sequenceID: 2, heading: 1.5, reference: .magnetic, deviation: -0.01, variation: 0.12),
      [0x02, 0x98, 0x3a, 0x9c, 0xff, 0xb0, 0x04, 0xfd]
    ),
    // not available
    (
      VesselHeading(
        sequenceID: nil, heading: nil, reference: .unavailable, deviation: nil, variation: nil),
      [0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff]
    ),
    // defaults
    (
      VesselHeading(sequenceID: 2, heading: 1.5, reference: .magnetic),
      [0x02, 0x98, 0x3a, 0xff, 0x7f, 0xff, 0x7f, 0xfd]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: VesselHeading, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: VesselHeading, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(VesselHeading.self, from: Self.vectors[0].1)
  }
}
