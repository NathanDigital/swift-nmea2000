// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 126993 Heartbeat")
struct HeartbeatTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN126993`.
  static let vectors: [(Heartbeat, [UInt8])] = [
    // typical
    (
      Heartbeat(interval: 60, sequenceCounter: 3),
      [0x60, 0xea, 0x03, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // widest field: 65535 ms is also the not-available value
    (
      Heartbeat(interval: 65.535, sequenceCounter: 0),
      [0xff, 0xff, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // zero
    (
      Heartbeat(interval: 0, sequenceCounter: 1),
      [0x00, 0x00, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // over the limit
    (
      Heartbeat(interval: 655.321, sequenceCounter: nil),
      [0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: Heartbeat, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 7)
  }

  static let decodedValues: [Int: Heartbeat] = [
    // 0xffff is not available.
    1: with(vectors[1].0) { $0.interval = nil },
    // 0xfffe decodes as the interval it encodes.
    3: with(vectors[3].0) { $0.interval = 65.534 },
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(Heartbeat.self, from: Self.vectors[0].1)
  }

  @Test func sendsIntervalsTooLongForTheFieldAsOutOfRange() {
    // Deliberate divergence: upstream sends the low 16 bits of the
    // milliseconds (upstream-vectors "PGN126993 over the field" and "at the
    // limit" give 0x0000 and 0xffd8).
    expectEncodes(
      Heartbeat(interval: 65.536, sequenceCounter: 252),
      as: [0xfe, 0xff, 0xfc, 0xff, 0xff, 0xff, 0xff, 0xff], priority: 7)
    expectEncodes(
      Heartbeat(interval: 655.32, sequenceCounter: nil),
      as: [0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], priority: 7)
    expectEncodes(
      Heartbeat(interval: -1, sequenceCounter: nil),
      as: [0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], priority: 7)
  }

  @Test func sendsNotAvailable() {
    expectEncodes(
      Heartbeat(interval: nil, sequenceCounter: nil),
      as: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], priority: 7)
  }
}
