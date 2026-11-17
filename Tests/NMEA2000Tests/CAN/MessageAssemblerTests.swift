// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

/// Frames received in order by one assembler, and the messages upstream's
/// node delivers for them, from `scripts/upstream-vectors "Frames receive"`.
struct AssemblerCase: Sendable, CustomTestStringConvertible {
  /// A received frame, and when it arrived in milliseconds from the start,
  /// if later than the previous frame.
  struct TimedFrame: Sendable {
    var frame: CANFrame
    var time: UInt32?
  }

  var name: String
  var frames: [TimedFrame]
  var messages: [Message]

  init(_ name: String, frames: [TimedFrame], messages: [Message]) {
    self.name = name
    self.frames = frames
    self.messages = messages
  }

  var testDescription: String { name }
}

private func frame(_ id: UInt32, _ data: [UInt8], at time: UInt32? = nil)
  -> AssemblerCase.TimedFrame
{
  AssemblerCase.TimedFrame(frame: CANFrame(id: id, data: data), time: time)
}

/// Feeds frames to an assembler from time `start`, returning the messages
/// with their time stamps cleared.
private func assemble(
  _ frames: [AssemblerCase.TimedFrame], into assembler: inout MessageAssembler,
  start: UInt32 = 1000
) -> [Message] {
  var time = start
  var messages: [Message] = []
  for timed in frames {
    if let offset = timed.time { time = start &+ offset }
    if var message = assembler.receive(timed.frame, at: time)?.message {
      message.timestamp = 0
      messages.append(message)
    }
  }
  return messages
}

@Suite("Message assembler")
struct MessageAssemblerTests {
  static let cases: [AssemblerCase] = [
    AssemblerCase(
      "single frame",
      frames: [frame(0x09f8_0117, [1, 2, 3, 4, 5, 6, 7, 8])],
      messages: [
        Message(
          pgn: 129025, priority: 2, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
      ]),
    AssemblerCase(
      "short single frame",
      frames: [frame(0x09f1_0d17, [1, 2, 3])],
      messages: [
        Message(
          pgn: 127245, priority: 2, source: 23,
          data: [0x01, 0x02, 0x03])
      ]),
    AssemblerCase(
      "addressed",
      frames: [frame(0x18ea_4217, [0x10, 0xf0, 0x01])],
      messages: [
        Message(
          pgn: 59904, priority: 6, source: 23, destination: 66,
          data: [0x10, 0xf0, 0x01])
      ]),
    AssemblerCase(
      "fast packet",
      frames: [
        frame(0x0df8_0517, [0x40, 15, 1, 2, 3, 4, 5, 6]),
        frame(0x0df8_0517, [0x41, 7, 8, 9, 10, 11, 12, 13]),
        frame(0x0df8_0517, [0x42, 14, 15, 0xff, 0xff, 0xff, 0xff, 0xff]),
      ],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 23,
          data: [
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e,
            0x0f,
          ])
      ]),
    AssemblerCase(
      "fast packet with short last frame",
      frames: [
        frame(0x0df8_0517, [0x20, 9, 1, 2, 3, 4, 5, 6]),
        frame(0x0df8_0517, [0x21, 7, 8, 9]),
      ],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])
      ]),
    AssemblerCase(
      "fast packet in one frame",
      frames: [frame(0x0df8_0517, [0x00, 4, 1, 2, 3, 4, 0xff, 0xff])],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 23,
          data: [0x01, 0x02, 0x03, 0x04])
      ]),
    AssemblerCase(
      "fast packet with a lost frame",
      frames: [
        frame(0x0df8_0517, [0x40, 15, 1, 2, 3, 4, 5, 6]),
        frame(0x0df8_0517, [0x42, 14, 15, 0xff, 0xff, 0xff, 0xff, 0xff]),
        frame(0x0df8_0517, [0x41, 7, 8, 9, 10, 11, 12, 13]),
      ],
      messages: []),
    AssemblerCase(
      "fast packet restarted",
      frames: [
        frame(0x0df8_0517, [0x40, 15, 1, 2, 3, 4, 5, 6]),
        frame(0x0df8_0517, [0x60, 9, 1, 2, 3, 4, 5, 6]),
        frame(0x0df8_0517, [0x61, 7, 8, 9]),
      ],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])
      ]),
    AssemblerCase(
      "orphan continuation frame",
      frames: [frame(0x0df8_0517, [0x41, 7, 8, 9, 10, 11, 12, 13])],
      messages: []),
    AssemblerCase(
      "interleaved sources",
      frames: [
        frame(0x0df8_0517, [0x00, 9, 1, 2, 3, 4, 5, 6]),
        frame(0x0df8_0518, [0x20, 9, 11, 12, 13, 14, 15, 16]),
        frame(0x0df8_0518, [0x21, 17, 18, 19]),
        frame(0x0df8_0517, [0x01, 7, 8, 9]),
      ],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 24,
          data: [0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13]),
        Message(
          pgn: 129029, priority: 3, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09]),
      ]),
    AssemblerCase(
      "too many open fast packets",
      frames: (1...6).map { frame(0x0df8_0500 | $0, [0x00, 9, 1, 2, 3, 4, 5, 6]) }
        + (1...6).map { frame(0x0df8_0500 | $0, [0x01, 7, 8, UInt8($0)]) },
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 1,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x01]),
        Message(
          pgn: 129029, priority: 3, source: 2,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x02]),
        Message(
          pgn: 129029, priority: 3, source: 3,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x03]),
        Message(
          pgn: 129029, priority: 3, source: 4,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x04]),
        Message(
          pgn: 129029, priority: 3, source: 5,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x05]),
      ]),
    AssemblerCase(
      "stale buffer reused after 100 ms",
      frames: (1...5).map {
        frame(0x0df8_0500 | $0, [0x00, 9, 1, 2, 3, 4, 5, 6], at: ($0 - 1) * 10)
      }
        + [
          // The oldest buffer is 99 ms old: not reused yet. At 100 ms it is.
          frame(0x0df8_0506, [0x00, 9, 1, 2, 3, 4, 5, 6], at: 99),
          frame(0x0df8_0506, [0x00, 9, 1, 2, 3, 4, 5, 6], at: 100),
          frame(0x0df8_0506, [0x01, 7, 8, 6]),
          frame(0x0df8_0501, [0x01, 7, 8, 1]),
          frame(0x0df8_0502, [0x01, 7, 8, 2]),
        ],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 6,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x06]),
        Message(
          pgn: 129029, priority: 3, source: 2,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x02]),
      ]),
    AssemblerCase(
      "busy buffers kept for 99 ms",
      frames: (1...5).map {
        frame(0x0df8_0500 | $0, [0x00, 9, 1, 2, 3, 4, 5, 6], at: ($0 - 1) * 10)
      }
        + [
          frame(0x0df8_0506, [0x00, 9, 1, 2, 3, 4, 5, 6], at: 99),
          frame(0x0df8_0506, [0x01, 7, 8, 6]),
          frame(0x0df8_0501, [0x01, 7, 8, 1]),
        ],
      messages: [
        Message(
          pgn: 129029, priority: 3, source: 1,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x01])
      ]),
    AssemblerCase(
      "fast packet longer than the buffer",
      frames: [frame(0x0df8_0517, [0x00, 230, 1, 2, 3, 4, 5, 6])]
        + (1..<32).map { frame(0x0df8_0517, [UInt8($0), 7, 7, 7, 7, 7, 7, 7]) },
      messages: []),
    AssemblerCase(
      "unknown PGN",
      frames: [frame(0x1cff_1417, [1, 2, 3, 4, 5, 6, 7, 8])],
      messages: [
        Message(
          pgn: 65300, priority: 7, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
      ]),
    AssemblerCase(
      "long unknown PGN frame",
      frames: [frame(0x1cff_1417, [1, 2, 3])],
      messages: [
        Message(
          pgn: 65300, priority: 7, source: 23,
          data: [0x01, 0x02, 0x03])
      ]),
    AssemblerCase(
      "proprietary fast packet",
      frames: [
        frame(0x19ff_0017, [0x00, 8, 1, 2, 3, 4, 5, 6]),
        frame(0x19ff_0017, [0x01, 7, 8]),
      ],
      messages: [
        Message(
          pgn: 130816, priority: 6, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
      ]),
    AssemblerCase(
      "bits above the 29-bit identifier",
      frames: [frame(0x89f8_0117, [1, 2, 3, 4, 5, 6, 7, 8])],
      messages: [
        Message(
          pgn: 129025, priority: 2, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
      ]),
    AssemblerCase(
      "PDU2 with data page",
      frames: [frame(0x0bf8_0117, [1, 2, 3, 4, 5, 6, 7, 8])],
      messages: [
        Message(
          pgn: 129025, priority: 2, source: 23,
          data: [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
      ]),
    AssemblerCase(
      "first PDU2 PGN",
      frames: [frame(0x18f0_0017, [1, 2, 3, 4, 5, 6, 7, 8])],
      messages: [
        Message(pgn: 61440, priority: 6, source: 23, data: [1, 2, 3, 4, 5, 6, 7, 8])
      ]),
    AssemblerCase(
      "empty fast packet",
      frames: [frame(0x0df8_0517, [0x00, 0x00])],
      messages: [Message(pgn: 129029, priority: 3, source: 23, data: [])]),
    AssemblerCase(
      "busy buffers half a clock cycle later",
      // Buffers that look more than half the 32-bit clock old count as newer,
      // so they're never taken over.
      frames: (1...5).map { frame(0x0df8_0500 | $0, [0x00, 9, 1, 2, 3, 4, 5, 6]) }
        + [
          frame(0x0df8_0506, [0x00, 9, 1, 2, 3, 4, 5, 6], at: 0x7fff_ffff),
          frame(0x0df8_0506, [0x01, 7, 8, 6]),
          frame(0x0df8_0501, [0x01, 7, 8, 1]),
        ],
      messages: [
        Message(pgn: 129029, priority: 3, source: 1, data: [1, 2, 3, 4, 5, 6, 7, 8, 1])
      ]),
  ]

  @Test("Reassembles frames as upstream does", arguments: cases)
  func reassemblesAsUpstream(_ testCase: AssemblerCase) {
    var assembler = MessageAssembler()
    #expect(assemble(testCase.frames, into: &assembler) == testCase.messages)
  }

  @Test(
    "Times out busy buffers across a clock wrap", arguments: cases.filter { $0.name.contains("ms") }
  )
  func timesOutAcrossClockWrap(_ testCase: AssemblerCase) {
    var assembler = MessageAssembler()
    #expect(assemble(testCase.frames, into: &assembler, start: .max - 60) == testCase.messages)
  }

  @Test func dropsUnknownMessagesWhenAsked() {
    var assembler = MessageAssembler(handlesOnlyKnownMessages: true)
    let frames = [
      frame(0x1cff_1417, [1, 2, 3, 4, 5, 6, 7, 8]),
      frame(0x09f8_0117, [1, 2, 3, 4, 5, 6, 7, 8]),
    ]
    #expect(
      assemble(frames, into: &assembler) == [
        Message(pgn: 129025, priority: 2, source: 23, data: [1, 2, 3, 4, 5, 6, 7, 8])
      ])
  }

  @Test func stampsMessagesWithTheirFirstFrameTime() {
    var assembler = MessageAssembler()
    #expect(
      assembler.receive(CANFrame(id: 0x0df8_0517, data: [0, 9, 1, 2, 3, 4, 5, 6]), at: 500) == nil)
    let assembled = assembler.receive(CANFrame(id: 0x0df8_0517, data: [1, 7, 8, 9]), at: 520)
    #expect(assembled?.message.timestamp == 500)
  }

  @Test func marksSystemMessages() {
    var assembler = MessageAssembler()
    let request = assembler.receive(CANFrame(id: 0x18ea_4217, data: [0x10, 0xf0, 0x01]), at: 0)
    #expect(request?.isSystemMessage == true)
    let position = assembler.receive(
      CANFrame(id: 0x09f8_0117, data: [1, 2, 3, 4, 5, 6, 7, 8]), at: 0)
    #expect(position?.isSystemMessage == false)
  }

  @Test func ignoresFastPacketFramesTooShortToRead() {
    // Deliberate divergence: upstream reads leftover buffer bytes for these.
    var assembler = MessageAssembler()
    #expect(assembler.receive(CANFrame(id: 0x0df8_0517, data: []), at: 0) == nil)
    #expect(assembler.receive(CANFrame(id: 0x0df8_0517, data: [0x00]), at: 0) == nil)
  }

  @Test func reassemblesCatalogFastPacketPGNs() {
    var catalog = PGNCatalog()
    catalog.fastPacketPGNs.insert(130820)
    var assembler = MessageAssembler(catalog: catalog)
    let frames = [
      frame(0x19ff_0417, [0x00, 8, 1, 2, 3, 4, 5, 6]),
      frame(0x19ff_0417, [0x01, 7, 8]),
    ]
    let messages = assemble(frames, into: &assembler)
    #expect(messages.map(\.data) == [[1, 2, 3, 4, 5, 6, 7, 8]])
  }

  @Test func reassemblesTransportProtocolBroadcasts() throws {
    // A BAM for a 10-byte PGN 126464 from 0x42, then its two data packets.
    var assembler = MessageAssembler()
    #expect(
      assembler.receive(
        CANFrame(id: 0x18ec_ff42, data: [32, 10, 0, 2, 0xff, 0x00, 0xee, 0x01]), at: 1000) == nil)
    #expect(
      assembler.receive(CANFrame(id: 0x18eb_ff42, data: [1, 0, 1, 2, 3, 4, 5, 6]), at: 1050)
        == nil)
    let last = assembler.receive(
      CANFrame(id: 0x18eb_ff42, data: [2, 7, 8, 9, 0xff, 0xff, 0xff, 0xff]), at: 1100)
    let assembled = try #require(last)
    #expect(
      assembled.message
        == Message(
          pgn: 126464, priority: 7, source: 0x42, data: Array(0..<10), timestamp: 1100,
          isTransportProtocol: true))
    #expect(!assembled.isSystemMessage)
  }

  @Test func consumesTransportProtocolFrames() {
    // Upstream never delivers the transport protocol's own frames.
    var assembler = MessageAssembler()
    #expect(
      assembler.receive(
        CANFrame(id: 0x18ec_1742, data: [17, 5, 1, 0xff, 0xff, 0x00, 0xee, 0x01]), at: 0) == nil)
    #expect(
      assembler.receive(CANFrame(id: 0x18eb_1742, data: [1, 0, 1, 2, 3, 4, 5, 6]), at: 0) == nil)
  }

  @Test func ignoresTransportProtocolFramesTooShortToRead() {
    // Deliberate divergence: upstream reads leftover buffer bytes for these.
    var assembler = MessageAssembler()
    #expect(
      assembler.receive(
        CANFrame(id: 0x18ec_ff42, data: [32, 3, 0, 1, 0xff, 0x00, 0xee]), at: 0) == nil)
    #expect(assembler.receive(CANFrame(id: 0x18eb_ff42, data: []), at: 0) == nil)
    #expect(
      assembler.receive(
        CANFrame(id: 0x18ec_ff42, data: [32, 3, 0, 1, 0xff, 0x00, 0xee, 0x01]), at: 0) == nil)
    #expect(assembler.receive(CANFrame(id: 0x18eb_ff42, data: []), at: 0) == nil)
    #expect(
      assembler.receive(CANFrame(id: 0x18eb_ff42, data: [1, 1, 2, 3]), at: 0)?.message.data
        == [1, 2, 3])
  }
}
