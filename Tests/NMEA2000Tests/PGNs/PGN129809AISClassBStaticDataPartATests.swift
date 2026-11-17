// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129809 AISClassBStaticDataPartA")
struct AISClassBStaticDataPartATests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129809`.
  static let vectors: [(AISClassBStaticDataPartA, [UInt8])] = [
    // typical
    (
      AISClassBStaticDataPartA(
        messageID: 24, repeatIndicator: .initial, userID: 230_123_456, name: "sailing yacht",
        transceiverInformation: .channelBTransmission, sequenceID: 3),
      [
        0x18, 0xc0, 0x67, 0xb7, 0x0d, 0x53, 0x41, 0x49, 0x4c, 0x49, 0x4e, 0x47, 0x20, 0x59, 0x41,
        0x43, 0x48, 0x54, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0xe3, 0x03,
      ]
    ),
    // high field values and long name
    (
      AISClassBStaticDataPartA(
        messageID: 63, repeatIndicator: .final, userID: 0xffff_ffff,
        name: "A name far longer than twenty",
        transceiverInformation: AISTransceiverInformation(rawValue: 31), sequenceID: 0xfe),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0x41, 0x20, 0x4e, 0x41, 0x4d, 0x45, 0x20, 0x46, 0x41, 0x52,
        0x20, 0x4c, 0x4f, 0x4e, 0x47, 0x45, 0x52, 0x20, 0x54, 0x48, 0xff, 0xfe,
      ]
    ),
    // defaults
    (
      AISClassBStaticDataPartA(
        messageID: 24, repeatIndicator: .initial, userID: 230_000_002, name: "BOAT"),
      [
        0x18, 0x82, 0x85, 0xb5, 0x0d, 0x42, 0x4f, 0x41, 0x54, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40,
        0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0xe0, 0xff,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: AISClassBStaticDataPartA, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(AISClassBStaticDataPartA.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(AISClassBStaticDataPartA.self, from: Self.vectors[0].1)
  }
}
