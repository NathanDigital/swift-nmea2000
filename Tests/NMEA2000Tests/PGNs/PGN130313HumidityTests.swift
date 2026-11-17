// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 130313 Humidity")
struct HumidityTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN130313`.
  static let vectors: [(Humidity, [UInt8])] = [
    // typical
    (
      Humidity(sequenceID: 1, instance: 2, source: .inside, actualHumidity: 55.5, setHumidity: 50),
      [0x01, 0x02, 0x00, 0x33, 0x36, 0xd4, 0x30, 0xff]
    ),
    // undefined source
    (
      Humidity(
        sequenceID: 2, instance: 3, source: .undefined, actualHumidity: -2.5, setHumidity: nil),
      [0x02, 0x03, 0xff, 0x8f, 0xfd, 0xff, 0x7f, 0xff]
    ),
    // not available
    (
      Humidity(
        sequenceID: nil, instance: 0xff, source: .undefined, actualHumidity: nil, setHumidity: nil),
      [0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff]
    ),
    // defaults
    (
      Humidity(sequenceID: 1, instance: 0, source: .outside, actualHumidity: 80),
      [0x01, 0x00, 0x01, 0x20, 0x4e, 0xff, 0x7f, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Humidity, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 5)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(Humidity.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Humidity.self, from: Self.vectors[0].1)
  }
}
