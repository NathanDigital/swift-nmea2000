// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129283 CrossTrackError")
struct CrossTrackErrorTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129283`.
  static let vectors: [(CrossTrackError, [UInt8])] = [
    // typical
    (
      CrossTrackError(
        sequenceID: 11, mode: .differential, isNavigationTerminated: true, crossTrackError: -12.34),
      [0x0b, 0x41, 0x2e, 0xfb, 0xff, 0xff, 0xff, 0xff]
    ),
    // not available
    (
      CrossTrackError(
        sequenceID: nil, mode: .autonomous, isNavigationTerminated: false, crossTrackError: nil),
      [0xff, 0x00, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff]
    ),
    // unknown mode
    (
      CrossTrackError(
        sequenceID: 11, mode: CrossTrackErrorMode(rawValue: 10), isNavigationTerminated: false,
        crossTrackError: 1.5),
      [0x0b, 0x0a, 0x96, 0x00, 0x00, 0x00, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: CrossTrackError, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 3)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: CrossTrackError, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(CrossTrackError.self, from: Self.vectors[0].1)
  }

  @Test(
    "Decodes both bits of navigation terminated",
    arguments: [(UInt8(0b00), Bool?.some(false)), (0b01, true), (0b10, nil), (0b11, nil)])
  func decodesNavigationTerminated(bits: UInt8, expected: Bool?) throws {
    // Deliberate divergence: upstream decodes only bit 6, reading error and
    // not available as true.
    var bytes = Self.vectors[0].1
    bytes[1] = bytes[1] & 0x0f | bits << 6
    let decoded = try CrossTrackError(Message(pgn: 129283, data: bytes))
    #expect(decoded.isNavigationTerminated == expected)
    #expect(decoded.makeMessage().data[1] == bytes[1] & 0x0f | (expected == nil ? 0xc0 : bits << 6))
  }
}
