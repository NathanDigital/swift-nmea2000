// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129038 AISClassAPositionReport")
struct AISClassAPositionReportTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129038`.
  static let vectors: [(AISClassAPositionReport, [UInt8])] = [
    // typical
    (
      AISClassAPositionReport(
        messageID: 1, repeatIndicator: .initial, userID: 230_123_456, isPositionAccurate: true,
        isRAIMInUse: false,
        timestampSecond: 42, transceiverInformation: .channelBTransmission,
        navigationStatus: .underWayMotoring, latitude: 60.1234567,
        longitude: -24.9876543, courseOverGround: 1.5, speedOverGround: 6.25,
        heading: 1.55,
        rateOfTurn: -0.01, sequenceID: 7),
      [
        0x01, 0xc0, 0x67, 0xb7, 0x0d, 0xc1, 0x2f, 0x1b, 0xf1, 0x87, 0x1c, 0xd6, 0x23, 0xa9, 0x98,
        0x3a, 0x71, 0x02, 0xff, 0xff, 0x1f, 0x8c, 0x3c, 0xc0, 0xfe, 0xf0, 0xfc, 0x07,
      ]
    ),
    // high field values
    (
      AISClassAPositionReport(
        messageID: 63, repeatIndicator: .final, userID: 0xffff_ffff, isPositionAccurate: false,
        isRAIMInUse: true,
        timestampSecond: 63, transceiverInformation: AISTransceiverInformation(rawValue: 31),
        navigationStatus: AISNavigationStatus(rawValue: 13), latitude: -33.8688,
        longitude: 151.2093, courseOverGround: 0,
        speedOverGround: 0, heading: 0,
        rateOfTurn: 0.02, sequenceID: 0xfe),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0x48, 0xb5, 0x20, 0x5a, 0x00, 0x08, 0xd0, 0xeb, 0xfe, 0x00,
        0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x00, 0x00, 0x80, 0x02, 0xfd, 0xfc, 0xfe,
      ]
    ),
    // not available
    (
      AISClassAPositionReport(
        messageID: 3, repeatIndicator: .first, userID: 0, isPositionAccurate: false,
        isRAIMInUse: false,
        timestampSecond: 60, transceiverInformation: .channelAReception, navigationStatus: .aisSART,
        latitude: nil,
        longitude: nil, courseOverGround: nil, speedOverGround: nil,
        heading: nil,
        rateOfTurn: nil, sequenceID: nil),
      [
        0x43, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xf0, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0x07, 0xff, 0xff, 0xff, 0x7f, 0xfe, 0xfc, 0xff,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: AISClassAPositionReport, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 4)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: AISClassAPositionReport, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(AISClassAPositionReport.self, from: Self.vectors[0].1)
  }
}
