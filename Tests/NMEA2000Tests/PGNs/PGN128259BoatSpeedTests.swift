// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128259 BoatSpeed")
struct BoatSpeedTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128259`.
  static let vectors: [(BoatSpeed, [UInt8])] = [
    // typical
    (
      BoatSpeed(
        sequenceID: 7, waterReferenced: 3.5, groundReferenced: 3.62, referenceType: .paddleWheel),
      [0x07, 0x5e, 0x01, 0x6a, 0x01, 0x00, 0xff, 0xff]
    ),
    // not available
    (
      BoatSpeed(
        sequenceID: nil, waterReferenced: nil, groundReferenced: nil,
        referenceType: .electromagnetic),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0x04, 0xff, 0xff]
    ),
    // unavailable sensor type
    (
      BoatSpeed(
        sequenceID: 7, waterReferenced: 3.5, groundReferenced: nil, referenceType: .unavailable),
      [0x07, 0x5e, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // sensor error
    (
      BoatSpeed(sequenceID: 7, waterReferenced: nil, groundReferenced: 3.62, referenceType: .error),
      [0x07, 0xff, 0xff, 0x6a, 0x01, 0xfe, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: BoatSpeed, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(BoatSpeed.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(BoatSpeed.self, from: Self.vectors[0].1)
  }

  @Test(
    "Decodes the four-bit error and unavailable codes",
    arguments: [
      (UInt8(0xff), SpeedWaterReferenceType.unavailable),
      (0x0f, .unavailable),
      (0xfe, .error),
      (0x0e, .error),
      (0x04, .electromagnetic),
      (0xf4, .electromagnetic),
    ])
  func decodesReferenceTypeCodes(byte: UInt8, expected: SpeedWaterReferenceType) throws {
    // Deliberate divergence: upstream decodes 14 and 15 as raw values that don't equal
    // its own N2kSWRT_Error and N2kSWRT_Unavailable constants.
    var bytes = Self.vectors[0].1
    bytes[5] = byte
    #expect(try BoatSpeed(Message(pgn: 128259, data: bytes)).referenceType == expected)
  }
}
