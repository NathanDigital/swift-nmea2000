// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129810 AISClassBStaticDataPartB")
struct AISClassBStaticDataPartBTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129810`.
  static let vectors: [(AISClassBStaticDataPartB, [UInt8])] = [
    // typical
    (
      AISClassBStaticDataPartB(
        messageID: 24, repeatIndicator: .initial, userID: 230_123_456, vesselType: 36,
        vendor: "acme01", callsign: "oh2xyz",
        mothershipID: 0, length: 12.5, beam: 4.25, positionReferenceStarboard: 2.0,
        positionReferenceBow: 9.5, transceiverInformation: .channelATransmission, sequenceID: 4),
      [
        0x18, 0xc0, 0x67, 0xb7, 0x0d, 0x24, 0x41, 0x43, 0x4d, 0x45, 0x30, 0x31, 0x40, 0x4f, 0x48,
        0x32, 0x58, 0x59, 0x5a, 0x40, 0x7d, 0x00, 0x2b, 0x00, 0x14, 0x00, 0x5f, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x03, 0xe2, 0x04,
      ]
    ),
    // high field values
    (
      AISClassBStaticDataPartB(
        messageID: 63, repeatIndicator: .final, userID: 0xffff_ffff, vesselType: 255,
        vendor: "VENDOR12", callsign: "CäLL",
        mothershipID: 0xffff_ffff, length: 0, beam: 0, positionReferenceStarboard: 0,
        positionReferenceBow: 0, transceiverInformation: AISTransceiverInformation(rawValue: 31),
        sequenceID: 0xfe),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x56, 0x45, 0x4e, 0x44, 0x4f, 0x52, 0x31, 0x43, 0x3f,
        0x3f, 0x4c, 0x4c, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff,
        0xff, 0xff, 0x03, 0xff, 0xfe,
      ]
    ),
    // not available
    (
      AISClassBStaticDataPartB(
        messageID: 24, repeatIndicator: .initial, userID: 0, vesselType: 0, vendor: "",
        callsign: "",
        mothershipID: 0, length: nil, beam: nil, positionReferenceStarboard: nil,
        positionReferenceBow: nil, transceiverInformation: .channelAReception, sequenceID: nil),
      [
        0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40,
        0x40, 0x40, 0x40, 0x40, 0x40, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00,
        0x00, 0x00, 0x03, 0xe0, 0xff,
      ]
    ),
    // defaults
    (
      AISClassBStaticDataPartB(
        messageID: 24, repeatIndicator: .initial, userID: 230_000_003, vesselType: 37, vendor: "V",
        callsign: "C",
        mothershipID: 0, length: 8, beam: 3, positionReferenceStarboard: 1,
        positionReferenceBow: 4),
      [
        0x18, 0x83, 0x85, 0xb5, 0x0d, 0x25, 0x56, 0x40, 0x40, 0x40, 0x40, 0x40, 0x40, 0x43, 0x40,
        0x40, 0x40, 0x40, 0x40, 0x40, 0x50, 0x00, 0x1e, 0x00, 0x0a, 0x00, 0x28, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x03, 0xe1, 0xff,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: AISClassBStaticDataPartB, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  /// What the vectors that encoding changes decode to, by index in `vectors`.
  static let decodedValues: [Int: AISClassBStaticDataPartB] = [
    // AIS text is upper-cased and truncated, with non-ASCII bytes sent as "?".
    0: with(vectors[0].0) {
      $0.vendor = "ACME01"
      $0.callsign = "OH2XYZ"
    },
    1: with(vectors[1].0) {
      $0.vendor = "VENDOR1"
      $0.callsign = "C??LL"
    },
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(AISClassBStaticDataPartB.self, from: Self.vectors[0].1)
  }
}
