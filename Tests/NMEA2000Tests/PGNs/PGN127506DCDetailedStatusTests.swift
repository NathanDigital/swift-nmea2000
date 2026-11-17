// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127506 DCDetailedStatus")
struct DCDetailedStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127506`.
  static let vectors: [(DCDetailedStatus, [UInt8])] = [
    // typical
    (
      DCDetailedStatus(
        sequenceID: 1, dcInstance: 2, dcType: .windGenerator, stateOfCharge: 87, stateOfHealth: 95,
        timeRemaining: 7200, rippleVoltage: 0.025, capacity: 720000),
      [0x01, 0x02, 0x04, 0x57, 0x5f, 0x78, 0x00, 0x19, 0x00, 0xc8, 0x00]
    ),
    // not available
    (
      DCDetailedStatus(
        sequenceID: nil, dcInstance: 0xff, dcType: DCSourceType(rawValue: 0xff), stateOfCharge: nil,
        stateOfHealth: nil,
        timeRemaining: nil, rippleVoltage: nil, capacity: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      DCDetailedStatus(
        sequenceID: 1, dcInstance: 0, dcType: .battery, stateOfCharge: 50, stateOfHealth: 100,
        timeRemaining: 3600),
      [0x01, 0x00, 0x00, 0x32, 0x64, 0x3c, 0x00, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: DCDetailedStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(DCDetailedStatus.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(DCDetailedStatus.self, from: Self.vectors[0].1)
  }
}
