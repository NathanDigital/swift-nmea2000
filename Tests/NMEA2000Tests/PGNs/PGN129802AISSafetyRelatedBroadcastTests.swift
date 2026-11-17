// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129802 AISSafetyRelatedBroadcast")
struct AISSafetyRelatedBroadcastTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129802`.
  static let vectors: [(AISSafetyRelatedBroadcast, [UInt8])] = [
    // typical
    (
      AISSafetyRelatedBroadcast(
        messageID: 14, repeatIndicator: .initial, sourceID: 230_123_456,
        transceiverInformation: .channelATransmission, text: "MOB ALERT near buoy 5"),
      [
        0x0e, 0xc0, 0x67, 0xb7, 0x0d, 0x05, 0x17, 0x01, 0x4d, 0x4f, 0x42, 0x20, 0x41, 0x4c, 0x45,
        0x52, 0x54, 0x20, 0x6e, 0x65, 0x61, 0x72, 0x20, 0x62, 0x75, 0x6f, 0x79, 0x20, 0x35, 0xff,
      ]
    ),
    // high field values and non-ASCII text
    (
      AISSafetyRelatedBroadcast(
        messageID: 63, repeatIndicator: .final, sourceID: 0xffff_ffff,
        transceiverInformation: AISTransceiverInformation(rawValue: 31), text: "Varå storm"),
      [
        0xff, 0xff, 0xff, 0xff, 0x3f, 0x3f, 0x0c, 0x01, 0x56, 0x61, 0x72, 0x3f, 0x20, 0x73, 0x74,
        0x6f, 0x72, 0x6d, 0xff,
      ]
    ),
    // empty text
    (
      AISSafetyRelatedBroadcast(
        messageID: 14, repeatIndicator: .second, sourceID: 1,
        transceiverInformation: .channelBReception, text: ""),
      [0x8e, 0x01, 0x00, 0x00, 0x00, 0x03, 0x02, 0x01, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: AISSafetyRelatedBroadcast, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(AISSafetyRelatedBroadcast.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(AISSafetyRelatedBroadcast.self, from: Self.vectors[0].1)
  }
}
