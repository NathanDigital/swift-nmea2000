// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127252 Heave")
struct HeaveTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127252`.
  static let vectors: [(Heave, [UInt8])] = [
    // typical
    (
      Heave(sequenceID: 4, heave: -1.25, delay: 0.5, delaySource: .factoryDefault),
      [0x04, 0x83, 0xff, 0x32, 0x00, 0xf2, 0xff, 0xff]
    ),
    // not available
    (
      Heave(sequenceID: nil, heave: nil, delay: nil, delaySource: .unavailable),
      [0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Heave, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(Heave.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Heave.self, from: Self.vectors[0].1)
  }
}
