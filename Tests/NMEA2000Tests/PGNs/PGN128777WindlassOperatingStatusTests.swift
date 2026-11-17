// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128777 WindlassOperatingStatus")
struct WindlassOperatingStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128777`.
  static let vectors: [(WindlassOperatingStatus, [UInt8])] = [
    // typical
    (
      WindlassOperatingStatus(
        sequenceID: 6, windlassID: 1, rodeCounter: 45.6, lineSpeed: 0.35, motionState: .retrieving,
        rodeType: .rope, anchorDockingState: .fullyDocked,
        operatingEvents: WindlassOperatingEvents(rawValue: 0x11)),
      [0x06, 0x01, 0xf6, 0xc8, 0x01, 0x23, 0x00, 0x45]
    ),
    // other values
    (
      WindlassOperatingStatus(
        sequenceID: 7, windlassID: 2, rodeCounter: 0, lineSpeed: 0, motionState: .unavailable,
        rodeType: .unavailable, anchorDockingState: .error,
        operatingEvents: WindlassOperatingEvents(rawValue: 0x1f)),
      [0x07, 0x02, 0xff, 0x00, 0x00, 0x00, 0x00, 0x7e]
    ),
    // not available
    (
      WindlassOperatingStatus(
        sequenceID: nil, windlassID: 0xff, rodeCounter: nil, lineSpeed: nil, motionState: .stopped,
        rodeType: .chain, anchorDockingState: .unavailable, operatingEvents: []),
      [0xff, 0xff, 0xf0, 0xff, 0xff, 0xff, 0xff, 0x03]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: WindlassOperatingStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(WindlassOperatingStatus.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(WindlassOperatingStatus.self, from: Self.vectors[0].1)
  }

  @Test func decodesOnlyDefinedOperatingEventBits() throws {
    // Upstream's tN2kDD483::SetEvents keeps only the five defined bits.
    var bytes = Self.vectors[0].1
    bytes[7] = 0xff
    let decoded = try WindlassOperatingStatus(Message(pgn: 128777, data: bytes))
    #expect(decoded.operatingEvents.rawValue == 0x1f)
    #expect(decoded.anchorDockingState == .unavailable)
  }
}
