// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127497 EngineTripParameters")
struct EngineTripParametersTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127497`.
  static let vectors: [(EngineTripParameters, [UInt8])] = [
    // typical
    (
      EngineTripParameters(
        instance: 1, tripFuelUsed: 125, fuelRateAverage: 15.5, fuelRateEconomy: -2.5,
        instantaneousFuelEconomy: 18.25),
      [0x01, 0x7d, 0x00, 0x9b, 0x00, 0xe7, 0xff, 0xb7, 0x00]
    ),
    // not available
    (
      EngineTripParameters(
        instance: 0xff, tripFuelUsed: nil, fuelRateAverage: nil, fuelRateEconomy: nil,
        instantaneousFuelEconomy: nil),
      [0xff, 0xff, 0xff, 0xff, 0x7f, 0xff, 0x7f, 0xff, 0x7f]
    ),
    // defaults
    (
      EngineTripParameters(instance: 0, tripFuelUsed: 40, fuelRateAverage: 12.5),
      [0x00, 0x28, 0x00, 0x7d, 0x00, 0xff, 0x7f, 0xff, 0x7f]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: EngineTripParameters, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: EngineTripParameters, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(EngineTripParameters.self, from: Self.vectors[0].1)
  }
}
