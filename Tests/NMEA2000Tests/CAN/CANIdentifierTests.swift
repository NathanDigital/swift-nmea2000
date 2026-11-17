// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("CAN identifier")
struct CANIdentifierTests {
  /// Identifiers from upstream's node (`scripts/upstream-vectors Frames`).
  @Test(
    "Round-trips upstream's identifiers",
    arguments: [
      (0x09f8_0117, CANIdentifier(priority: 2, pgn: 129025, source: 23, destination: 0xff)),
      (0x18ea_4217, CANIdentifier(priority: 6, pgn: 59904, source: 23, destination: 0x42)),
      (0x0ded_4217, CANIdentifier(priority: 3, pgn: 126208, source: 23, destination: 0x42)),
      (0x19ef_ff17, CANIdentifier(priority: 6, pgn: 126720, source: 23, destination: 0xff)),
      (0x1cff_1417, CANIdentifier(priority: 7, pgn: 65300, source: 23, destination: 0xff)),
    ] as [(UInt32, CANIdentifier)])
  func roundTrips(id: UInt32, header: CANIdentifier) {
    #expect(CANIdentifier(frameID: id) == header)
    #expect(header.frameID == id)
  }

  @Test func ignoresDestinationOfBroadcastPGNs() {
    let header = CANIdentifier(priority: 2, pgn: 129025, source: 23, destination: 0x42)
    #expect(header.frameID == 0x09f8_0117)
    #expect(!header.isAddressable)
  }

  @Test func ignoresBitsOutsideTheHeader() {
    // Bits above the 29-bit identifier and the extended data page bit.
    let expected = CANIdentifier(priority: 2, pgn: 129025, source: 23, destination: 0xff)
    #expect(CANIdentifier(frameID: 0x89f8_0117) == expected)
    #expect(CANIdentifier(frameID: 0x0bf8_0117) == expected)
  }

  @Test("Rejects PGNs that can't be sent", arguments: [59905, 0x4_0000] as [UInt32])
  func rejectsInvalidPGNs(pgn: UInt32) {
    #expect(CANIdentifier(priority: 6, pgn: pgn, source: 23, destination: 0xff).frameID == nil)
  }

  @Test func masksPriority() {
    let header = CANIdentifier(priority: 0x0a, pgn: 129025, source: 23, destination: 0xff)
    #expect(header.frameID == 0x09f8_0117)
  }
}
