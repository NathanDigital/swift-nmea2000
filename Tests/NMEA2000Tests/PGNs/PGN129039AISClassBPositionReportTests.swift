// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129039 AISClassBPositionReport")
struct AISClassBPositionReportTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129039`.
  static let vectors: [(AISClassBPositionReport, [UInt8])] = [
    // typical
    (
      AISClassBPositionReport(
        messageID: 18, repeatIndicator: .second, userID: 211_234_567, latitude: 54.321,
        longitude: 10.123,
        isPositionAccurate: true, isRAIMInUse: true, timestampSecond: 30, courseOverGround: 3.0,
        speedOverGround: 2.5, transceiverInformation: .channelAReception, heading: 3.05,
        unitType: .classBCS,
        hasDisplay: true, hasDSC: false, canUseWholeBand: true, acceptsMessage22: false,
        mode: .assigned,
        isCommunicationStateITDMA: false, sequenceID: 9),
      [
        0x92, 0x07, 0x2f, 0x97, 0x0c, 0xb0, 0xa5, 0x08, 0x06, 0x10, 0xba, 0x60, 0x20, 0x7b, 0x30,
        0x75, 0xfa, 0x00, 0xff, 0xff, 0x07, 0x24, 0x77, 0xff, 0xac, 0xfe, 0x09,
      ]
    ),
    // other flags
    (
      AISClassBPositionReport(
        messageID: 63, repeatIndicator: .final, userID: 1, latitude: -1.5, longitude: -2.5,
        isPositionAccurate: false, isRAIMInUse: false, timestampSecond: 63, courseOverGround: 0,
        speedOverGround: 0, transceiverInformation: AISTransceiverInformation(rawValue: 31),
        heading: 0, unitType: .classBSOTDMA,
        hasDisplay: false, hasDSC: true, canUseWholeBand: false, acceptsMessage22: true,
        mode: .autonomous,
        isCommunicationStateITDMA: true, sequenceID: nil),
      [
        0xff, 0x01, 0x00, 0x00, 0x00, 0xc0, 0x87, 0x82, 0xfe, 0x40, 0x1e, 0x1b, 0xff, 0xfc, 0x00,
        0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x00, 0x00, 0xff, 0x50, 0xff, 0xff,
      ]
    ),
    // not available
    (
      AISClassBPositionReport(
        messageID: 19, repeatIndicator: .initial, userID: 0, latitude: nil, longitude: nil,
        isPositionAccurate: false, isRAIMInUse: false, timestampSecond: 60, courseOverGround: nil,
        speedOverGround: nil, transceiverInformation: .channelBReception, heading: nil,
        unitType: .classBSOTDMA,
        hasDisplay: false, hasDSC: false, canUseWholeBand: false, acceptsMessage22: false,
        mode: .autonomous,
        isCommunicationStateITDMA: false, sequenceID: nil),
      [
        0x13, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xf0, 0xff,
        0xff, 0xff, 0xff, 0xff, 0xff, 0x0f, 0xff, 0xff, 0xff, 0x00, 0xfe, 0xff,
      ]
    ),
    // unknown unit type without display
    (
      AISClassBPositionReport(
        messageID: 18, repeatIndicator: .initial, userID: 2, latitude: 1.0, longitude: 2.0,
        isPositionAccurate: false, isRAIMInUse: true, timestampSecond: 10, courseOverGround: 1.0,
        speedOverGround: 1.0, transceiverInformation: .channelAReception, heading: 1.0,
        unitType: AISUnitType(rawValue: 3),
        hasDisplay: false, hasDSC: false, canUseWholeBand: false, acceptsMessage22: false,
        mode: .autonomous,
        isCommunicationStateITDMA: false, sequenceID: 1),
      [
        0x12, 0x02, 0x00, 0x00, 0x00, 0x00, 0x2d, 0x31, 0x01, 0x80, 0x96, 0x98, 0x00, 0x2a, 0x10,
        0x27, 0x64, 0x00, 0xff, 0xff, 0x07, 0x10, 0x27, 0xff, 0x04, 0xfe, 0x01,
      ]
    ),
    // display without class B CS
    (
      AISClassBPositionReport(
        messageID: 18, repeatIndicator: .initial, userID: 3, latitude: 1.0, longitude: 2.0,
        isPositionAccurate: true, isRAIMInUse: false, timestampSecond: 11, courseOverGround: 1.0,
        speedOverGround: 1.0, transceiverInformation: .channelAReception, heading: 1.0,
        unitType: .classBSOTDMA,
        hasDisplay: true, hasDSC: false, canUseWholeBand: false, acceptsMessage22: false,
        mode: .autonomous,
        isCommunicationStateITDMA: false, sequenceID: 2),
      [
        0x12, 0x03, 0x00, 0x00, 0x00, 0x00, 0x2d, 0x31, 0x01, 0x80, 0x96, 0x98, 0x00, 0x2d, 0x10,
        0x27, 0x64, 0x00, 0xff, 0xff, 0x07, 0x10, 0x27, 0xff, 0x08, 0xfe, 0x02,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: AISClassBPositionReport, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 4)
  }

  /// What the vectors that encoding changes decode to, by index in `vectors`.
  static let decodedValues: [Int: AISClassBPositionReport] = [
    // The unit type is a one-bit field.
    3: with(vectors[3].0) { $0.unitType = AISUnitType(rawValue: 1) }
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(AISClassBPositionReport.self, from: Self.vectors[0].1)
  }
}
