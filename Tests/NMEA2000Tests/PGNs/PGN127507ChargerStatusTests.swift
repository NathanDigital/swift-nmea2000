// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 127507 ChargerStatus")
struct ChargerStatusTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN127507`.
  static let vectors: [(ChargerStatus, [UInt8])] = [
    // typical
    (
      ChargerStatus(
        instance: 1, batteryInstance: 2, chargeState: .absorption, chargerMode: .secondary,
        enabled: .on,
        equalizationPending: .off, equalizationTimeRemaining: 5400),
      [0x01, 0x02, 0x22, 0xf1, 0x5a, 0x00]
    ),
    // high values
    (
      ChargerStatus(
        instance: 3, batteryInstance: 4, chargeState: .error, chargerMode: .unavailable,
        enabled: .error,
        equalizationPending: .unavailable, equalizationTimeRemaining: 0),
      [0x03, 0x04, 0xfe, 0xfe, 0x00, 0x00]
    ),
    // not available
    (
      ChargerStatus(
        instance: 0xff, batteryInstance: 0xff, chargeState: .unavailable, chargerMode: .unavailable,
        enabled: .unavailable,
        equalizationPending: .unavailable, equalizationTimeRemaining: nil),
      [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
    ),
    // defaults
    (
      ChargerStatus(instance: 0, batteryInstance: 1, chargeState: .bulk),
      [0x00, 0x01, 0x01, 0xfd, 0xff, 0xff]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ChargerStatus, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ChargerStatus, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ChargerStatus.self, from: Self.vectors[0].1)
  }

  @Test func sendsEqualizationTimeInMinutes() {
    // Deliberate divergence: upstream's encoder sends seconds, but the field and
    // upstream's own decoder use minutes.
    let message = ChargerStatus(
      instance: 0, batteryInstance: 0, chargeState: .bulk, equalizationTimeRemaining: 5400
    ).makeMessage()
    #expect(message.data.suffix(2) == [0x5a, 0x00])
  }
}
