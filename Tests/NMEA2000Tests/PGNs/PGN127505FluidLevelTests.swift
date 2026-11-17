// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127505 FluidLevel")
struct FluidLevelTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127505`.
  static let vectors: [(FluidLevel, [UInt8])] = [
    // typical
    (
      FluidLevel(instance: 2, fluidType: .blackWater, level: 75.5, capacity: 120.5),
      [0x52, 0xbb, 0x49, 0xb5, 0x04, 0x00, 0x00, 0xff]
    ),
    // high instance and type
    (
      FluidLevel(instance: 0x0e, fluidType: .error, level: -1.0, capacity: 4000),
      [0xee, 0x06, 0xff, 0x40, 0x9c, 0x00, 0x00, 0xff]
    ),
    // not available
    (
      FluidLevel(instance: 0x0f, fluidType: .unavailable, level: nil, capacity: nil),
      [0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: FluidLevel, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: FluidLevel, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(FluidLevel.self, from: Self.vectors[0].1)
  }
}
