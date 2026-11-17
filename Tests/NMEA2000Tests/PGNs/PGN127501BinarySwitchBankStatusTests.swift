// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127501 BinarySwitchBankStatus")
struct BinarySwitchBankStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127501`.
  static let vectors: [(BinarySwitchBankStatus, [UInt8])] = [
    // four switches
    (
      BinarySwitchBankStatus(instance: 3, statuses: [.on, .off, .error, .unavailable]),
      [0x03, 0xe1, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // full bank from a packed value
    (
      BinarySwitchBankStatus(
        instance: 4,
        statuses: Array(repeating: [.off, .on, .error, .unavailable], count: 7).flatMap { $0 }),
      [0x04, 0xe4, 0xe4, 0xe4, 0xe4, 0xe4, 0xe4, 0xe4]
    ),
    // no switches
    (
      BinarySwitchBankStatus(instance: 0, statuses: []),
      [0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: BinarySwitchBankStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  /// What the vectors that encoding changes decode to, by index in `vectors`.
  static let decodedValues: [Int: BinarySwitchBankStatus] = [
    // Encoding pads the bank to 28 statuses with "unavailable".
    0: with(vectors[0].0) { $0.statuses += repeatElement(.unavailable, count: 24) },
    2: with(vectors[2].0) { $0.statuses = Array(repeating: .unavailable, count: 28) },
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(BinarySwitchBankStatus.self, from: Self.vectors[0].1)
  }
}
