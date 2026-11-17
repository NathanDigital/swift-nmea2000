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

  @Test func decodesOnlyLowNibbleOfReferenceType() throws {
    // Upstream writes the whole byte but masks it to four bits when parsing.
    let message = BoatSpeed(
      sequenceID: 1, waterReferenced: nil, groundReferenced: nil, referenceType: .unavailable
    ).makeMessage()
    #expect(message.data[5] == 0xff)
    #expect(try BoatSpeed(message).referenceType.rawValue == 0x0f)
  }
}
