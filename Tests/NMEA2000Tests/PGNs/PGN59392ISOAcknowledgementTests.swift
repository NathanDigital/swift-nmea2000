// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 59392 ISO Acknowledgement")
struct ISOAcknowledgementTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN59392`.
  static let vectors: [(ISOAcknowledgement, [UInt8])] = [
    // typical
    (
      ISOAcknowledgement(control: 1, pgn: 126998),
      [0x01, 0xff, 0xff, 0xff, 0xff, 0x16, 0xf0, 0x01]
    ),
    // high bits
    (
      ISOAcknowledgement(control: 0xf2, pgn: 0x3ffff, groupFunction: 0x81),
      [0xf2, 0x81, 0xff, 0xff, 0xff, 0xff, 0xff, 0x03]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ISOAcknowledgement, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ISOAcknowledgement, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ISOAcknowledgement.self, from: Self.vectors[0].1)
  }
}
