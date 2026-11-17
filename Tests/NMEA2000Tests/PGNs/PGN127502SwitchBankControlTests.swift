// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127502 SwitchBankControl")
struct SwitchBankControlTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127502`.
  static let vectors: [(SwitchBankControl, [UInt8])] = [
    // four switches
    (
      SwitchBankControl(targetInstance: 5, statuses: [.unavailable, .error, .on, .off]),
      [0x05, 0x1b, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // full bank from a packed value
    (
      SwitchBankControl(
        targetInstance: 6,
        statuses: Array(repeating: [.unavailable, .error, .on, .off], count: 7).flatMap { $0 }),
      [0x06, 0x1b, 0x1b, 0x1b, 0x1b, 0x1b, 0x1b, 0x1b]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: SwitchBankControl, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(SwitchBankControl.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(SwitchBankControl.self, from: Self.vectors[0].1)
  }
}
