// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import Foundation
import NMEA2000
import Testing

@Suite("Message coding and errors")
struct MessageCodingTests {
  @Test func roundTripsThroughCodable() throws {
    let message = Message(
      pgn: 127250, priority: 2, source: 1, destination: 255, data: [1, 2, 0xff],
      timestamp: .milliseconds(1234), framing: .singleFrame)
    let json = try JSONEncoder().encode(message)
    #expect(try JSONDecoder().decode(Message.self, from: json) == message)
    let frame = CANFrame(id: 0x09f1_1201, data: [1, 2, 3])
    #expect(
      try JSONDecoder().decode(CANFrame.self, from: JSONEncoder().encode(frame)) == frame)
  }

  @Test func decodingKeepsOnlyThePriorityBits() throws {
    let json = try JSONEncoder().encode(Message(pgn: 127250, priority: 3))
    let text = try #require(String(data: json, encoding: .utf8))
    let edited = text.replacing("\"priority\":3", with: "\"priority\":11")
    #expect(edited != text)
    #expect(try JSONDecoder().decode(Message.self, from: Data(edited.utf8)).priority == 3)
  }

  @Test func gatewaysWrapTheTimestampToThirtyTwoBits() throws {
    // 2^32 + 0x01020304 milliseconds is sent as 0x01020304.
    var message = Message(pgn: 127250, source: 1, data: [1], timestamp: .milliseconds(0x0102_0304))
    let sentence = try Seasmart.encode(message)
    let bytes = try Actisense.encode(message)
    #expect(try Seasmart.decode(sentence).timestamp == .milliseconds(0x0102_0304))
    message.timestamp = .milliseconds(0x1_0102_0304 as Int64) + .microseconds(900)
    #expect(try Seasmart.encode(message) == sentence)
    #expect(try Actisense.encode(message) == bytes)
  }

  @Test func errorsDescribeThemselves() {
    #expect("\(NodeError.noSuchDevice(2))" == "The node has no device 2")
    #expect(
      "\(NodeError.invalidMessage(.invalidPGN(0)))"
        == "The message can't be framed: PGN 0 can't be sent")
    #expect(
      "\(FramingError.payloadTooLong(300))" == "Payload of 300 bytes is longer than 223 bytes")
    #expect(
      "\(GatewayError.checksumMismatch(expected: 0x2a, actual: 0x0b))" == "Checksum 0xb isn't 0x2a")
  }
}
