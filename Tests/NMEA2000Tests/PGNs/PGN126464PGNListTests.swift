// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 126464 PGN List")
struct PGNListTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN126464`.
  static let vectors: [(PGNList, [UInt8])] = [
    // transmit
    (
      PGNList(kind: .transmit, pgns: [59392, 126996, 0x3ffff]),
      [0x00, 0x00, 0xe8, 0x00, 0x14, 0xf0, 0x01, 0xff, 0xff, 0x03]
    ),
    // receive empty
    (
      PGNList(kind: .receive, pgns: []),
      [0x01]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: PGNList, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: PGNList, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(PGNList.self, from: Self.vectors[0].1)
  }

  @Test func ignoresATrailingPartialPGN() throws {
    let list = try PGNList(Message(pgn: 126464, data: [0x00, 0x00, 0xe8, 0x00, 0x14, 0xf0]))
    #expect(list.pgns == [59392])
  }

  @Test func keepsUnknownKinds() throws {
    let list = try PGNList(Message(pgn: 126464, data: [0x07]))
    #expect(list.kind.rawValue == 7)
    #expect(list.kind.description == "unknown (7)")
    #expect(PGNList.Kind.transmit.description == "transmit")
    #expect(PGNList.Kind.receive.description == "receive")
  }
}
