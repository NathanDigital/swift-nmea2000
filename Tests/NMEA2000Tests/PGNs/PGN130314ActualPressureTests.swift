// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130314 ActualPressure")
struct ActualPressureTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130314`.
  static let vectors: [(ActualPressure, [UInt8])] = [
    // typical
    (
      ActualPressure(sequenceID: 1, instance: 2, source: .hydraulic, pressure: 2_500_000.5),
      [0x01, 0x02, 0x04, 0x45, 0x78, 0x7d, 0x01, 0xff]
    ),
    // negative pressure
    (
      ActualPressure(sequenceID: 2, instance: 3, source: .error, pressure: -5000),
      [0x02, 0x03, 0xfe, 0xb0, 0x3c, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      ActualPressure(sequenceID: nil, instance: 0xff, source: .unavailable, pressure: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ActualPressure, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ActualPressure, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ActualPressure.self, from: Self.vectors[0].1)
  }
}
