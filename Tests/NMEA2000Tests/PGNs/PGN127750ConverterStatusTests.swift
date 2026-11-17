// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127750 ConverterStatus")
struct ConverterStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127750`.
  static let vectors: [(ConverterStatus, [UInt8])] = [
    // typical
    (
      ConverterStatus(
        sequenceID: 1, connectionNumber: 2, operatingState: .inverting, temperatureState: .warning,
        overloadState: .ok, lowDCVoltageState: .warning, rippleState: .high),
      [0x01, 0x02, 0x09, 0x91, 0xff, 0xff, 0xff, 0xff]
    ),
    // other values
    (
      ConverterStatus(
        sequenceID: 3, connectionNumber: 4, operatingState: .hub1, temperatureState: .ok,
        overloadState: .overload, lowDCVoltageState: .ok, rippleState: .warning),
      [0x03, 0x04, 0xfc, 0x48, 0xff, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      ConverterStatus(
        sequenceID: nil, connectionNumber: 0xff, operatingState: .unavailable,
        temperatureState: .unavailable,
        overloadState: .unavailable, lowDCVoltageState: .unavailable, rippleState: .unavailable),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ConverterStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ConverterStatus, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ConverterStatus.self, from: Self.vectors[0].1)
  }
}
