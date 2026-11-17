// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128267 WaterDepth")
struct WaterDepthTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128267`.
  static let vectors: [(WaterDepth, [UInt8])] = [
    // typical
    (
      WaterDepth(sequenceID: 8, depthBelowTransducer: 12.34, offset: -0.5, range: 100),
      [0x08, 0xd2, 0x04, 0x00, 0x00, 0x0c, 0xfe, 0x0a]
    ),
    // not available
    (
      WaterDepth(sequenceID: nil, depthBelowTransducer: nil, offset: nil, range: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff]
    ),
    // defaults
    (
      WaterDepth(sequenceID: 8, depthBelowTransducer: 12.34, offset: -0.5),
      [0x08, 0xd2, 0x04, 0x00, 0x00, 0x0c, 0xfe, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: WaterDepth, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: WaterDepth, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(WaterDepth.self, from: Self.vectors[0].1)
  }
}
