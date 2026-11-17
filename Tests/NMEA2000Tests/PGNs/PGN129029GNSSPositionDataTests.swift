// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129029 GNSSPositionData")
struct GNSSPositionDataTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129029`.
  static let vectors: [(GNSSPositionData, [UInt8])] = [
    // one reference station
    (
      GNSSPositionData(
        sequenceID: 10, daysSince1970: 19000, secondsSinceMidnight: 43200.5, latitude: 60.1234567,
        longitude: -151.2093, altitude: 12.5, gnssType: .gpsSBAS, method: .dgnss, satelliteCount: 9,
        horizontalDilution: 0.8, positionDilution: 1.6, geoidalSeparation: 18.2,
        referenceStations: [.init(type: .gps, id: 42, ageOfCorrection: 3.5)]),
      [
        0x0a, 0x38, 0x4a, 0x88, 0xdf, 0xbf, 0x19, 0x00, 0x86, 0xb8, 0x38, 0xa7, 0x03, 0x58, 0x08,
        0x00, 0x2f, 0xa5, 0x8b, 0x6d, 0xf7, 0x03, 0xeb, 0x20, 0xbc, 0xbe, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x23, 0xfd, 0x09, 0x50, 0x00, 0xa0, 0x00, 0x1c, 0x07, 0x00, 0x00, 0x01, 0xa0, 0x02,
        0x5e, 0x01,
      ]
    ),
    // no reference stations
    (
      GNSSPositionData(
        sequenceID: 10, daysSince1970: 19000, secondsSinceMidnight: 43200.5, latitude: 60.1234567,
        longitude: -151.2093, altitude: 12.5, gnssType: .gpsSBAS, method: .dgnss, satelliteCount: 9,
        horizontalDilution: 0.8, positionDilution: 1.6, geoidalSeparation: 18.2,
        referenceStations: []),
      [
        0x0a, 0x38, 0x4a, 0x88, 0xdf, 0xbf, 0x19, 0x00, 0x86, 0xb8, 0x38, 0xa7, 0x03, 0x58, 0x08,
        0x00, 0x2f, 0xa5, 0x8b, 0x6d, 0xf7, 0x03, 0xeb, 0x20, 0xbc, 0xbe, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x23, 0xfd, 0x09, 0x50, 0x00, 0xa0, 0x00, 0x1c, 0x07, 0x00, 0x00, 0x00,
      ]
    ),
    // not available
    (
      GNSSPositionData(
        sequenceID: nil, daysSince1970: nil, secondsSinceMidnight: nil, latitude: nil,
        longitude: nil,
        altitude: nil, gnssType: .gps, method: .unavailable, satelliteCount: nil,
        horizontalDilution: nil,
        positionDilution: nil, geoidalSeparation: nil, referenceStations: nil),
      [
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f,
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
        0x7f, 0xf0, 0xfd, 0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xff,
      ]
    ),
    // Galileo with an old correction
    (
      GNSSPositionData(
        sequenceID: 10, daysSince1970: 19000, secondsSinceMidnight: 43200.5, latitude: -33.8688,
        longitude: 151.2093, altitude: -5.25, gnssType: .galileo, method: .rtkFixed,
        satelliteCount: 12,
        horizontalDilution: 0.6, positionDilution: 1.1, geoidalSeparation: -22.5,
        referenceStations: [.init(type: .galileo, id: 4000, ageOfCorrection: 400.0)]),
      [
        0x0a, 0x38, 0x4a, 0x88, 0xdf, 0xbf, 0x19, 0x00, 0x00, 0x50, 0xf6, 0x0e, 0xbd, 0x4c, 0xfb,
        0x00, 0xd1, 0x5a, 0x74, 0x92, 0x08, 0xfc, 0x14, 0x30, 0xe4, 0xaf, 0xff, 0xff, 0xff, 0xff,
        0xff, 0x48, 0xfd, 0x0c, 0x3c, 0x00, 0x6e, 0x00, 0x36, 0xf7, 0xff, 0xff, 0x01, 0x08, 0xfa,
        0x40, 0x9c,
      ]
    ),
    // defaults
    (
      GNSSPositionData(
        sequenceID: 10, daysSince1970: 19000, secondsSinceMidnight: 43200.5, latitude: 60.1234567,
        longitude: -151.2093, altitude: 12.5, gnssType: .gps, method: .gnssFix, satelliteCount: 9,
        horizontalDilution: 0.8),
      [
        0x0a, 0x38, 0x4a, 0x88, 0xdf, 0xbf, 0x19, 0x00, 0x86, 0xb8, 0x38, 0xa7, 0x03, 0x58, 0x08,
        0x00, 0x2f, 0xa5, 0x8b, 0x6d, 0xf7, 0x03, 0xeb, 0x20, 0xbc, 0xbe, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x10, 0xfd, 0x09, 0x50, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: GNSSPositionData, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: GNSSPositionData, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(GNSSPositionData.self, from: Self.vectors[0].1)
  }

  @Test func decodesEveryReferenceStation() throws {
    var bytes = Self.vectors[1].1  // No reference stations.
    bytes[bytes.count - 1] = 2
    bytes += [0x01, 0x01, 0x64, 0x00, 0x22, 0x02, 0xc8, 0x00]
    let stations = try GNSSPositionData(Message(pgn: 129029, data: bytes)).referenceStations
    #expect(
      stations == [
        .init(type: .glonass, id: 16, ageOfCorrection: 1),
        .init(type: .gpsGLONASS, id: 34, ageOfCorrection: 2),
      ])
  }

  @Test func sendsOnlyTheFirstReferenceStation() throws {
    // Upstream's SetN2kPGN129029 takes one station, and sends a count of 1.
    var position = try GNSSPositionData(Message(pgn: 129029, data: Self.vectors[0].1))
    let first = try #require(position.referenceStations?.first)
    position.referenceStations = [first, .init(type: .glonass, id: 16, ageOfCorrection: 1)]
    #expect(position.makeMessage().data == Self.vectors[0].1)
  }
}
