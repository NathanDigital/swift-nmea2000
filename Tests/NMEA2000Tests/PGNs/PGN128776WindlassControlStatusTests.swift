// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 128776 WindlassControlStatus")
struct WindlassControlStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN128776`.
  static let vectors: [(WindlassControlStatus, [UInt8])] = [
    // typical
    (
      WindlassControlStatus(
        sequenceID: 4, windlassID: 1, directionControl: .up, speedControl: 75,
        speedControlType: .proportionalSpeed, anchorDockingControl: .yes, powerEnable: .yes,
        mechanicalLock: .error,
        deckAndAnchorWash: .unavailable, anchorLight: .no, commandTimeout: 1.25,
        controlEvents: .anotherDeviceControllingWindlass),
      [0x04, 0x01, 0xe6, 0x4b, 0x39, 0xfa, 0x01]
    ),
    // other values
    (
      WindlassControlStatus(
        sequenceID: 5, windlassID: 2, directionControl: WindlassDirectionControl(rawValue: 3),
        speedControl: 0,
        speedControlType: .unavailable, anchorDockingControl: .unavailable, powerEnable: .error,
        mechanicalLock: .unavailable,
        deckAndAnchorWash: .yes, anchorLight: .error, commandTimeout: 0.5, controlEvents: []),
      [0x05, 0x02, 0xff, 0x00, 0x9e, 0x64, 0x00]
    ),
    // not available
    (
      WindlassControlStatus(
        sequenceID: nil, windlassID: 0xff, directionControl: .off, speedControl: 0xff,
        speedControlType: .singleSpeed, anchorDockingControl: .no, powerEnable: .no,
        mechanicalLock: .no,
        deckAndAnchorWash: .no, anchorLight: .no, commandTimeout: nil, controlEvents: []),
      [0xff, 0xff, 0xc0, 0xff, 0x00, 0xff, 0x00]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: WindlassControlStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 2)
  }

  @Test("Decodes upstream bytes", arguments: vectors.map(\.1))
  func decodes(bytes: [UInt8]) throws {
    try expectDecodes(WindlassControlStatus.self, from: bytes)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(WindlassControlStatus.self, from: Self.vectors[0].1)
  }

  @Test func decodesOnlyDefinedControlEventBits() throws {
    // Upstream's tN2kDD478::SetEvents keeps only bit 0.
    var bytes = Self.vectors[0].1
    bytes[6] = 0xff
    let decoded = try WindlassControlStatus(Message(pgn: 128776, data: bytes))
    #expect(decoded.controlEvents.rawValue == 0x01)
  }
}
