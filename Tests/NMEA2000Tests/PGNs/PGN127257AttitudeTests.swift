// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127257 Attitude")
struct AttitudeTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127257`.
  static let vectors: [(Attitude, [UInt8])] = [
    // typical
    (
      Attitude(sequenceID: 5, yaw: 1.0, pitch: -0.1, roll: 0.2),
      [0x05, 0x10, 0x27, 0x18, 0xfc, 0xd0, 0x07, 0xff]
    ),
    // not available
    (
      Attitude(sequenceID: nil, yaw: nil, pitch: nil, roll: nil),
      [0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0x7f, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Attitude, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(Attitude.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Attitude.self, from: Self.vectors[0].1)
  }
}
