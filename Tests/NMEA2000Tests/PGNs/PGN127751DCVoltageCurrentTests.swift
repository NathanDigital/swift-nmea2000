// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127751 DCVoltageCurrent")
struct DCVoltageCurrentTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127751`.
  static let vectors: [(DCVoltageCurrent, [UInt8])] = [
    // typical
    (
      DCVoltageCurrent(instance: 1, voltage: 12.6, current: 35.25, sequenceID: 9),
      [0x09, 0x01, 0x7e, 0x00, 0xc5, 0x0d, 0x00, 0xff, 0xff]
    ),
    // negative current
    (
      DCVoltageCurrent(instance: 2, voltage: 48.0, current: -1234.56, sequenceID: 10),
      [0x0a, 0x02, 0xe0, 0x01, 0xc0, 0x1d, 0xfe, 0xff, 0xff]
    ),
    // not available
    (
      DCVoltageCurrent(instance: 0xff, voltage: nil, current: nil, sequenceID: nil),
      [0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
    // defaults
    (
      DCVoltageCurrent(instance: 0, voltage: 13.1),
      [0x01, 0x00, 0x83, 0x00, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: DCVoltageCurrent, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(DCVoltageCurrent.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(DCVoltageCurrent.self, from: Self.vectors[0].1)
  }
}
