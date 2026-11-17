// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129026 COGSOGRapidUpdate")
struct COGSOGRapidUpdateTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129026`.
  static let vectors: [(COGSOGRapidUpdate, [UInt8])] = [
    // typical
    (
      COGSOGRapidUpdate(
        sequenceID: 9, reference: .true, courseOverGround: 1.234, speedOverGround: 5.67),
      [0x09, 0xfc, 0x34, 0x30, 0x37, 0x02, 0xff, 0xff]
    ),
    // not available
    (
      COGSOGRapidUpdate(
        sequenceID: nil, reference: .unavailable, courseOverGround: nil, speedOverGround: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: COGSOGRapidUpdate, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(COGSOGRapidUpdate.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(COGSOGRapidUpdate.self, from: Self.vectors[0].1)
  }
}
