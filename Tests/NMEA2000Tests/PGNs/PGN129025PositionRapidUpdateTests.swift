// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 129025 PositionRapidUpdate")
struct PositionRapidUpdateTests {
  static let vectors: [(PositionRapidUpdate, [UInt8])] = [
    (
      PositionRapidUpdate(latitude: 60.1234567, longitude: -151.2093),
      [0x87, 0x1c, 0xd6, 0x23, 0xb8, 0x4a, 0xdf, 0xa5]
    ),
    (
      PositionRapidUpdate(latitude: nil, longitude: nil),
      [0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: PositionRapidUpdate, expected: [UInt8]) {
    let message = value.makeMessage()
    #expect(message.pgn == 129025)
    #expect(message.priority == 2)
    #expect(message.destination == Message.broadcastAddress)
    #expect(message.data == expected)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ expected: PositionRapidUpdate, bytes: [UInt8]) throws {
    let decoded = try PositionRapidUpdate(Message(pgn: 129025, data: bytes))
    #expect(decoded.latitude.isApproximatelyEqual(to: expected.latitude, tolerance: 1e-7))
    #expect(decoded.longitude.isApproximatelyEqual(to: expected.longitude, tolerance: 1e-7))
  }

  @Test func shortPayloadDecodesAsNotAvailable() throws {
    let decoded = try PositionRapidUpdate(
      Message(pgn: 129025, data: [0x87, 0x1c, 0xd6, 0x23]))
    #expect(decoded.latitude != nil)
    #expect(decoded.longitude == nil)
  }

  @Test func ignoresTrailingBytes() throws {
    let data: [UInt8] = [0x87, 0x1c, 0xd6, 0x23, 0xb8, 0x4a, 0xdf, 0xa5, 0x01, 0x02]
    let decoded = try PositionRapidUpdate(Message(pgn: 129025, data: data))
    #expect(decoded.longitude != nil)
  }

  @Test func rejectsOtherPGN() {
    #expect(throws: MessageDecodingError.unexpectedPGN(expected: 129025, actual: 129026)) {
      try PositionRapidUpdate(Message(pgn: 129026, data: [UInt8](repeating: 0, count: 8)))
    }
  }

  @Test func overridesPriorityAndDestination() {
    let message = PositionRapidUpdate(latitude: 0, longitude: 0)
      .makeMessage(priority: 5, destination: 0x23)
    #expect(message.priority == 5)
    #expect(message.destination == 0x23)
  }
}
