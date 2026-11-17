// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129539 GNSSDOPData")
struct GNSSDOPDataTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129539`.
  static let vectors: [(GNSSDOPData, [UInt8])] = [
    // typical
    (
      GNSSDOPData(
        sequenceID: 13, desiredMode: .threeDimensional, actualMode: .automatic,
        horizontalDilution: 0.9,
        verticalDilution: 1.1, timeDilution: 0.7),
      [0x0d, 0xda, 0x5a, 0x00, 0x6e, 0x00, 0x46, 0x00]
    ),
    // not available
    (
      GNSSDOPData(
        sequenceID: nil, desiredMode: .unavailable, actualMode: .error, horizontalDilution: nil,
        verticalDilution: nil, timeDilution: nil),
      [0xff, 0xf7, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0x7f]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: GNSSDOPData, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(GNSSDOPData.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(GNSSDOPData.self, from: Self.vectors[0].1)
  }
}
