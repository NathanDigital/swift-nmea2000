// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

private let typical = Message(
  pgn: 127250, priority: 2, source: 1, destination: 255, data: [1, 2, 3, 4, 5, 6, 7, 8],
  timestamp: 0x0102_0304)

/// The bytes upstream writes for `typical`
/// (`scripts/upstream-vectors "Actisense write typical"`).
private let typicalBytes: [UInt8] = [
  0x10, 0x02, 0x93, 0x13, 0x02, 0x12, 0xf1, 0x01, 0xff, 0x01, 0x04, 0x03, 0x02, 0x01, 0x08, 0x01,
  0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x1e, 0x10, 0x03,
]

private let escapes = Message(
  pgn: 0x1f010, priority: 6, source: 0x10, destination: 0x10, data: [0x10, 0x02, 0x10, 0x03],
  timestamp: 0x1010_1010)

/// The bytes upstream writes for `escapes`.
private let escapeBytes: [UInt8] = [
  0x10, 0x02, 0x93, 0x0f, 0x06, 0x10, 0x10, 0xf0, 0x01, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10,
  0x10, 0x10, 0x10, 0x10, 0x10, 0x04, 0x10, 0x10, 0x02, 0x10, 0x10, 0x03, 0xce, 0x10, 0x03,
]

private let short = Message(
  pgn: 130306, priority: 2, source: 7, destination: 255, data: [1, 2, 3], timestamp: 1234)

@Suite("Actisense")
struct ActisenseTests {
  @Test func encodesAsUpstreamDoes() {
    #expect(Actisense.encode(typical) == typicalBytes)
    #expect(Actisense.encode(escapes) == escapeBytes)
  }

  @Test func escapesAChecksumOf0x10() {
    // upstream-vectors "Actisense write checksum to escape"
    let message = Message(
      pgn: 130306, priority: 2, source: 7, destination: 255, data: [1, 2, 0x6b], timestamp: 1234)
    #expect(
      Actisense.encode(message) == [
        0x10, 0x02, 0x93, 0x0e, 0x02, 0x02, 0xfd, 0x01, 0xff, 0x07, 0xd2, 0x04, 0x00, 0x00, 0x03,
        0x01, 0x02, 0x6b, 0x10, 0x10, 0x10, 0x03,
      ])
  }

  @Test func encodesTheLongestMessage() {
    // upstream-vectors "Actisense write long"
    let message = Message(
      pgn: 126996, priority: 6, source: 33, destination: 255,
      data: (0..<223).map { UInt8(0x20 + $0 % 0x50) }, timestamp: 0xffff_fffe)
    #expect(
      Actisense.encode(message) == [
        0x10, 0x02, 0x93, 0xea, 0x06, 0x14, 0xf0, 0x01, 0xff, 0x21, 0xfe, 0xff, 0xff, 0xff, 0xdf,
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e,
        0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d,
        0x3e, 0x3f, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c,
        0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b,
        0x5c, 0x5d, 0x5e, 0x5f, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a,
        0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
        0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38,
        0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47,
        0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56,
        0x57, 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x5f, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65,
        0x66, 0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x20, 0x21, 0x22, 0x23, 0x24,
        0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33,
        0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40, 0x41, 0x42,
        0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51,
        0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a, 0x5b, 0x5c, 0x5d, 0x5e, 0x4d, 0x10,
        0x03,
      ])
  }

  @Test func encodesMessagesTooLongForUpstreamsBuffer() throws {
    // Deliberate divergence: upstream's 8-bit output index wraps past 255
    // bytes, and every 0x10 here is doubled.
    let message = Message(
      pgn: 0x1f010, priority: 6, source: 0x10, destination: 0x10,
      data: Array(repeating: 0x10, count: 223), timestamp: 0x1010_1010)
    let bytes = try #require(Actisense.encode(message))
    #expect(bytes.count > 255)
    var decoder = ActisenseDecoder()
    #expect(decoder.decode(bytes, at: 0) == [message])
  }

  @Test func doesNotEncodeInvalidMessages() {
    #expect(Actisense.encode(Message(pgn: 0, data: [1])) == nil)
    #expect(Actisense.encode(Message(pgn: 127250, data: [])) == nil)
    // Upstream's message holds at most 223 bytes, and readers reject more.
    #expect(Actisense.encode(Message(pgn: 127250, data: Array(repeating: 1, count: 224))) == nil)
    #expect(Actisense.encode(Message(pgn: 127250, data: Array(repeating: 1, count: 245))) == nil)
  }

  @Test func decodesWhatUpstreamWrites() {
    var decoder = ActisenseDecoder()
    #expect(decoder.decode(typicalBytes, at: 0) == [typical])
    #expect(decoder.decode(escapeBytes, at: 0) == [escapes])
  }

  @Test func decodesByteByByte() {
    var decoder = ActisenseDecoder()
    var messages: [Message] = []
    for byte in typicalBytes {
      if let message = decoder.decode(byte, at: 0) { messages.append(message) }
    }
    #expect(messages == [typical])
  }

  @Test func skipsNoiseBetweenMessages() throws {
    // upstream-vectors "Actisense read two messages and noise"
    var decoder = ActisenseDecoder()
    let input =
      [0x41, 0x10, 0x10, 0x03, 0x02, 0x10] + typicalBytes + [0x55]
      + (try #require(Actisense.encode(short)))
    #expect(decoder.decode(input, at: 0) == [typical, short])
  }

  @Test func decodesRequestsWithTheDefaultSourceAndTheCurrentTime() {
    // upstream-vectors "Actisense read request"
    let body: [UInt8] = [0x94, 8, 3, 0x12, 0xf1, 0x01, 0x17, 2, 0xaa, 0xbb]
    let checksum = 0 &- body.reduce(0, &+)
    var decoder = ActisenseDecoder()
    #expect(
      decoder.decode([0x10, 0x02] + body + [checksum, 0x10, 0x03], at: 777) == [
        Message(
          pgn: 127250, priority: 3, source: 65, destination: 23, data: [0xaa, 0xbb],
          timestamp: 777)
      ])
    var custom = ActisenseDecoder(defaultSource: 9)
    #expect(custom.decode([0x10, 0x02] + body + [checksum, 0x10, 0x03], at: 0).first?.source == 9)
  }

  @Test func dropsMessagesThatDoNotCheckOut() {
    // upstream-vectors "Actisense read bad checksum", "wrong length",
    // "unknown type" and "data longer than a message"
    var decoder = ActisenseDecoder()
    var input = typicalBytes
    input[input.count - 3] ^= 1
    #expect(decoder.decode(input, at: 0).isEmpty)
    input = typicalBytes
    input[3] += 1
    #expect(decoder.decode(input, at: 0).isEmpty)
    input = typicalBytes
    input[15] += 1
    #expect(decoder.decode(input, at: 0).isEmpty)
    input = typicalBytes
    input[2] = 0xa0
    #expect(decoder.decode(input, at: 0).isEmpty)
    let body: [UInt8] =
      [0x93, 235, 2, 0x12, 0xf1, 0x01, 0xff, 0x01, 0, 0, 0, 0, 224]
      + Array(repeating: 0x20, count: 224)
    let checksum = 0 &- body.reduce(0, &+)
    #expect(decoder.decode([0x10, 0x02] + body + [checksum, 0x10, 0x03], at: 0).isEmpty)
    // The decoder recovers for the next message.
    #expect(decoder.decode(typicalBytes, at: 0) == [typical])
  }

  @Test func restartsAtAStartOfText() {
    // upstream-vectors "Actisense read restarted" and "broken escape"
    var decoder = ActisenseDecoder()
    #expect(
      decoder.decode([0x10, 0x02, 0x93, 0x05, 0x01, 0x10, 0x02] + typicalBytes.dropFirst(2), at: 0)
        == [typical])
    #expect(
      decoder.decode([0x10, 0x02, 0x93, 0x05, 0x10, 0x41] + typicalBytes, at: 0) == [typical])
  }

  @Test func dropsBodiesLongerThanTheBuffer() {
    // upstream-vectors "Actisense read too long"
    var decoder = ActisenseDecoder()
    let input = [0x10, 0x02, 0x93] + Array(repeating: UInt8(0x20), count: 300) + typicalBytes
    #expect(decoder.decode(input, at: 0) == [typical])
  }

  @Test func decodesAnEmptyPayload() {
    // upstream-vectors "Actisense read empty payload"
    var body: [UInt8] = [0x93, 11, 2, 0x12, 0xf1, 0x01, 0xff, 0x01, 4, 3, 2, 1, 0]
    body.append(0 &- body.reduce(0, &+))
    var decoder = ActisenseDecoder()
    #expect(
      decoder.decode([0x10, 0x02] + body + [0x10, 0x03], at: 0) == [
        Message(pgn: 127250, priority: 2, source: 1, destination: 255, timestamp: 0x0102_0304)
      ])
  }

  @Test func dropsAFullBodyThatCannotTakeAnEscapedByte() {
    // upstream-vectors "Actisense read full buffer then escaped escape"
    var decoder = ActisenseDecoder()
    let input =
      [0x10, 0x02, 0x93] + Array(repeating: UInt8(0x20), count: 299) + [0x10, 0x10]
      + typicalBytes.dropFirst()
    #expect(decoder.decode(input, at: 0).isEmpty)
  }

  @Test func keepsTheLowThreeBitsOfThePriority() {
    // Upstream keeps the whole byte; Message holds three bits.
    var body: [UInt8] = [0x93, 0x0c, 0x0e, 0x12, 0xf1, 0x01, 0xff, 0x01, 0, 0, 0, 0, 1, 0x55]
    body.append(0 &- body.reduce(0, &+))
    var decoder = ActisenseDecoder()
    #expect(decoder.decode([0x10, 0x02] + body + [0x10, 0x03], at: 0).first?.priority == 6)
  }
}
