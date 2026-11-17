// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127493 TransmissionParameters")
struct TransmissionParametersTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127493`.
  static let vectors: [(TransmissionParameters, [UInt8])] = [
    // typical
    (
      TransmissionParameters(
        instance: 1, gear: .reverse, oilPressure: 1_500_000, oilTemperature: 353.15,
        discreteStatus: [.check, .lowOilPressure, .sailDrive]),
      [0x01, 0xfe, 0x98, 0x3a, 0xcb, 0x0d, 0x15, 0xff]
    ),
    // not available
    (
      TransmissionParameters(
        instance: 0xff, gear: .unknown, oilPressure: nil, oilTemperature: nil,
        discreteStatus: [.overTemperature, .lowOilLevel]),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x0a, 0xff]
    ),
    // defaults
    (
      TransmissionParameters(
        instance: 0, gear: .forward, oilPressure: 1_000_000, oilTemperature: 340),
      [0x00, 0xfc, 0x10, 0x27, 0x48, 0x0d, 0x00, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: TransmissionParameters, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(TransmissionParameters.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(TransmissionParameters.self, from: Self.vectors[0].1)
  }
}
