// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129041 AISAtoNReport")
struct AISAtoNReportTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129041`.
  static let vectors: [(AISAtoNReport, [UInt8])] = [
    // typical
    (
      AISAtoNReport(
        messageID: 21, repeatIndicator: .initial, userID: 992_761_234, longitude: 24.9512,
        latitude: 60.1695,
        isPositionAccurate: true, isRAIMInUse: false, timestampSecond: 15, length: 5.5, beam: 2.5,
        positionReferenceStarboard: 1.2, positionReferenceTrueNorth: 2.75,
        atonType: .beaconCardinalNorth,
        isOffPosition: false, isVirtual: true, isAssignedMode: false, gnssType: .gpsGLONASS,
        atonStatus: 0,
        transceiverInformation: .channelATransmission, name: "Harmaja light"),
      [
        0x15, 0x92, 0x55, 0x2c, 0x3b, 0x40, 0x40, 0xdf, 0x0e, 0x18, 0x23, 0xdd, 0x23, 0x3d, 0x37,
        0x00, 0x19, 0x00, 0x0c, 0x00, 0x1c, 0x00, 0x49, 0xe4, 0x00, 0xe2, 0x0f, 0x01, 0x48, 0x61,
        0x72, 0x6d, 0x61, 0x6a, 0x61, 0x20, 0x6c, 0x69, 0x67, 0x68, 0x74,
      ]
    ),
    // high field values and long name
    (
      AISAtoNReport(
        messageID: 63, repeatIndicator: .final, userID: 1, longitude: -151.2093, latitude: -33.8688,
        isPositionAccurate: false, isRAIMInUse: true, timestampSecond: 63, length: 6553.0, beam: 0,
        positionReferenceStarboard: 0, positionReferenceTrueNorth: 0, atonType: .lightVessel,
        isOffPosition: true, isVirtual: false, isAssignedMode: true, gnssType: .galileo,
        atonStatus: 0xa5,
        transceiverInformation: AISTransceiverInformation(rawValue: 31),
        name: "Very long AtoN name äbove the 34 character limit"),
      [
        0xff, 0x01, 0x00, 0x00, 0x00, 0xb8, 0x4a, 0xdf, 0xa5, 0x00, 0x08, 0xd0, 0xeb, 0xfe, 0xfa,
        0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xbf, 0xf0, 0xa5, 0xff, 0x23, 0x01, 0x56, 0x65,
        0x72, 0x79, 0x20, 0x6c, 0x6f, 0x6e, 0x67, 0x20, 0x41, 0x74, 0x6f, 0x4e, 0x20, 0x6e, 0x61,
        0x6d, 0x65, 0x20, 0x3f, 0x62, 0x6f, 0x76, 0x65, 0x20, 0x74, 0x68, 0x65, 0x20, 0x33, 0x34,
        0x20,
      ]
    ),
    // defaults
    (
      AISAtoNReport(),
      [
        0x3f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xfc, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0xe0, 0xff, 0xe0, 0x02, 0x01,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: AISAtoNReport, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 4)
  }

  /// What the vectors that encoding changes decode to, by index in `vectors`.
  static let decodedValues: [Int: AISAtoNReport] = [
    // The name is truncated to 34 bytes, with non-ASCII bytes sent as "?".
    1: with(vectors[1].0) { $0.name = "Very long AtoN name ?bove the 34 " },
    // The message ID and timestamp are six-bit fields.
    2: with(vectors[2].0) {
      $0.messageID = 63
      $0.timestampSecond = 63
    },
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(AISAtoNReport.self, from: Self.vectors[0].1)
  }
}
