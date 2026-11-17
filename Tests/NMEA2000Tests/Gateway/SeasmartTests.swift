// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

private let typical = Message(
  pgn: 127250, priority: 2, source: 1, destination: 255,
  data: [1, 2, 3, 0xab, 0xcd, 0xef, 0x10, 0xff], timestamp: 0x0102_0304)

/// A sentence with its checksum, flipped by `wrong` and in lower case if
/// asked, as frames.cpp's `sentence` builds it.
private func sentence(_ body: String, wrong: UInt8 = 0, lower: Bool = false, tail: String = "")
  -> String
{
  let checksum = body.utf8.reduce(0, ^) ^ wrong
  let hex = String(checksum, radix: 16, uppercase: !lower)
  return "$" + body + "*" + (hex.count < 2 ? "0" : "") + hex + tail
}

@Suite("Seasmart")
struct SeasmartTests {
  @Test func encodesAsUpstreamDoes() {
    // upstream-vectors "Seasmart write"
    #expect(Seasmart.encode(typical) == "$PCDIN,01F112,01020304,01,010203ABCDEF10FF*26")
    #expect(
      Seasmart.encode(Message(pgn: 0x1ffff, priority: 7, source: 255, data: [0], timestamp: .max))
        == "$PCDIN,01FFFF,FFFFFFFF,FF,00*51")
    #expect(
      Seasmart.encode(Message(pgn: 59904, source: 0, destination: 0x42))
        == "$PCDIN,00EA00,00000000,00,*54")
  }

  @Test func decodesWhatUpstreamReads() throws {
    // upstream-vectors "Seasmart read"; the sentence carries no priority or
    // destination.
    let expected = Message(
      pgn: 127250, source: 1, data: typical.data, timestamp: 0x0102_0304)
    #expect(Seasmart.decode(sentence("PCDIN,01F112,01020304,01,010203ABCDEF10FF")) == expected)
    #expect(
      Seasmart.decode(sentence("PCDIN,01f112,01020304,01,010203abcdef10ff", lower: true))
        == expected)
    #expect(
      Seasmart.decode(sentence("PCDIN,01F112,01020304,01,010203ABCDEF10FF", tail: "\r\n"))
        == expected)
    #expect(
      Seasmart.decode(sentence("PCDIN,01F112,01020304,01,"))
        == Message(pgn: 127250, source: 1, timestamp: 0x0102_0304))
    #expect(Seasmart.decode(try #require(Seasmart.encode(typical)))?.data == typical.data)
  }

  @Test func doesNotEncodePayloadsLongerThanAMessage() throws {
    // Upstream's message holds at most 223 bytes, and decode rejects more.
    let longest = try #require(
      Seasmart.encode(Message(pgn: 127250, data: Array(repeating: 1, count: 223))))
    #expect(Seasmart.decode(longest)?.data.count == 223)
    #expect(Seasmart.encode(Message(pgn: 127250, data: Array(repeating: 1, count: 224))) == nil)
  }

  @Test(arguments: [
    sentence("pcdin,01f112,01020304,01,010203abcdef10ff", lower: true),
    sentence("PCDIN,01F112,01020304,01,010203ABCDEF10FF", wrong: 1),
    sentence("PCDIN,01F112,01020304,01,010203ABCDEF10F"),
    sentence("PCDIN,01F112;01020304,01,01"),
    sentence("PCDIN,01F112,01020304;01,01"),
    sentence("PCDIN,01F112,01020304,01;01"),
    "$PCDIN,01F112,01020304,01,01",
    sentence("PCDIN,01F112,01020304,01,0G"),
    sentence("PCDIN,01G112,01020304,01,01"),
    sentence("PCDIN,+1F112,01020304,01,01"),
    sentence("GPGGA,01F112,01020304,01,01"),
    "$PCDIN,01F112,0102",
    "$PCDIN,01F112,01020304,01,01*",
    "$PCDIN,01F112,01020304,01,01*0",
    sentence("PCDIN,01F014,00000000,21," + String(repeating: "A5", count: 224)),
  ])
  func rejectsWhatUpstreamRejects(_ text: String) {
    // upstream-vectors "Seasmart read rejects" and "Seasmart read longest"
    #expect(Seasmart.decode(text) == nil)
  }

  @Test func decodesTheLongestPayload() {
    // upstream-vectors "Seasmart read longest"
    let text = sentence("PCDIN,01F014,00000000,21," + String(repeating: "A5", count: 223))
    #expect(Seasmart.decode(text)?.data == Array(repeating: 0xa5, count: 223))
  }
}
