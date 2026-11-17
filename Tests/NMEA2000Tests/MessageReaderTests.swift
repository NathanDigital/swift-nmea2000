// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

/// A scaled field width, used to round-trip values through writer and reader.
enum ScaledField: String, CaseIterable, Sendable {
  case int8, uint8, int16, uint16, int24, uint24, int32, uint32, int64

  func write(_ value: Double?, resolution: Double, to writer: inout MessageWriter) {
    switch self {
    case .int8: writer.appendInt8(value, resolution: resolution)
    case .uint8: writer.appendUInt8(value, resolution: resolution)
    case .int16: writer.appendInt16(value, resolution: resolution)
    case .uint16: writer.appendUInt16(value, resolution: resolution)
    case .int24: writer.appendInt24(value, resolution: resolution)
    case .uint24: writer.appendUInt24(value, resolution: resolution)
    case .int32: writer.appendInt32(value, resolution: resolution)
    case .uint32: writer.appendUInt32(value, resolution: resolution)
    case .int64: writer.appendInt64(value, resolution: resolution)
    }
  }

  func read(resolution: Double, from reader: inout MessageReader) -> Double? {
    switch self {
    case .int8: reader.readInt8(resolution: resolution)
    case .uint8: reader.readUInt8(resolution: resolution)
    case .int16: reader.readInt16(resolution: resolution)
    case .uint16: reader.readUInt16(resolution: resolution)
    case .int24: reader.readInt24(resolution: resolution)
    case .uint24: reader.readUInt24(resolution: resolution)
    case .int32: reader.readInt32(resolution: resolution)
    case .uint32: reader.readUInt32(resolution: resolution)
    case .int64: reader.readInt64(resolution: resolution)
    }
  }

  var byteCount: Int {
    switch self {
    case .int8, .uint8: 1
    case .int16, .uint16: 2
    case .int24, .uint24: 3
    case .int32, .uint32: 4
    case .int64: 8
    }
  }

  var isSigned: Bool { rawValue.hasPrefix("int") }
}

@Suite("MessageReader")
struct MessageReaderTests {
  @Test("Round-trips scaled values", arguments: ScaledField.allCases)
  func roundTripsScaledValues(_ field: ScaledField) {
    let resolution = 0.01
    let values = field.isSigned ? [0, 1.23, -1.23] : [0, 1.23, 2.5]
    for value in values {
      var writer = MessageWriter()
      field.write(value, resolution: resolution, to: &writer)
      #expect(writer.count == field.byteCount)
      var reader = MessageReader(writer.data)
      let decoded = field.read(resolution: resolution, from: &reader)
      #expect(abs((decoded ?? .nan) - value) < resolution, "\(value) decoded as \(decoded as Any)")
      #expect(reader.remainingCount == 0)
    }
  }

  @Test("Round-trips not available", arguments: ScaledField.allCases)
  func roundTripsNotAvailable(_ field: ScaledField) {
    var writer = MessageWriter()
    field.write(nil, resolution: 1, to: &writer)
    var reader = MessageReader(writer.data)
    #expect(field.read(resolution: 1, from: &reader) == nil)
    #expect(reader.index == field.byteCount)
  }

  @Test("Returns nil past the end without moving", arguments: ScaledField.allCases)
  func scaledPastEnd(_ field: ScaledField) {
    var reader = MessageReader([UInt8](repeating: 0, count: field.byteCount - 1))
    #expect(field.read(resolution: 1, from: &reader) == nil)
    #expect(reader.index == 0)
  }

  @Test func readsRawIntegers() {
    var reader = MessageReader([
      0xab, 0xfe, 0xff, 0x34, 0x12, 0x56, 0x34, 0x12, 0x78, 0x56, 0x34, 0x12,
      0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01,
    ])
    #expect(reader.readUInt8() == 0xab)
    #expect(reader.readInt16() == -2)
    #expect(reader.readUInt16() == 0x1234)
    #expect(reader.readUInt24() == 0x12_3456)
    #expect(reader.readUInt32() == 0x1234_5678)
    #expect(reader.readUInt64() == 0x0102_0304_0506_0708)
    #expect(reader.remainingCount == 0)
  }

  @Test func rawIntegersPastEndReturnUpstreamDefaults() {
    var reader = MessageReader([])
    #expect(reader.readUInt8() == 0xff)
    #expect(reader.readInt16() == 0x7fff)
    #expect(reader.readUInt16() == 0xffff)
    #expect(reader.readUInt24() == 0xffff_ffff)
    #expect(reader.readUInt32() == 0xffff_ffff)
    #expect(reader.readUInt64() == .max)
  }

  @Test func readsOptionalIntegers() {
    var reader = MessageReader([
      0xff, 0x05, 0xff, 0x7f, 0xff, 0xff, 0x34, 0x12, 0xff, 0xff, 0xff, 0xff,
    ])
    #expect(reader.readOptionalUInt8() == nil)
    #expect(reader.readOptionalUInt8() == 5)
    #expect(reader.readOptionalInt16() == nil)
    #expect(reader.readOptionalUInt16() == nil)
    #expect(reader.readOptionalUInt16() == 0x1234)
    #expect(reader.readOptionalUInt32() == nil)
    #expect(reader.readOptionalUInt8() == nil)  // past the end
    #expect(reader.readOptionalInt8() == nil)  // past the end
    var signed = MessageReader([0x7f, 0xfe])
    #expect(signed.readOptionalInt8() == nil)
    #expect(signed.readOptionalInt8() == -2)
  }

  @Test func failedReadDoesNotConsumeBytes() {
    // Upstream leaves the index alone when a read doesn't fit, so a following
    // narrower read still sees the byte.
    var reader = MessageReader([0x01, 0x02, 0x03])
    reader.skip(2)
    #expect(reader.readUInt16() == 0xffff)
    #expect(reader.readUInt8() == 0x03)
  }

  @Test func decodesOutOfRangeAsValue() {
    // Upstream only maps "not available" to its sentinel; "out of range"
    // decodes as an ordinary value.
    var reader = MessageReader([0xfe])
    #expect(reader.readUInt8(resolution: 1) == 254)
  }

  @Test func signExtendsInt24() {
    var reader = MessageReader([0xff, 0xff, 0xff, 0x00, 0x00, 0x80])
    #expect(reader.readInt24(resolution: 0.01) == -0.01)
    #expect(reader.readInt24(resolution: 1) == -8_388_608)
  }

  @Test func readsFloat32() {
    var reader = MessageReader([
      0x00, 0x00, 0xc0, 0x3f, 0xff, 0xff, 0xff, 0x7f, 0x00, 0x00, 0xc0, 0x7f,
    ])
    #expect(reader.readFloat32() == 1.5)
    #expect(reader.readFloat32() == nil)
    #expect(reader.readFloat32() == nil)  // NaN
  }

  @Test func readsFixedString() {
    var reader = MessageReader([0x41, 0x42, 0xff, 0x43, 0x41, 0x40, 0x40, 0x41, 0x00, 0x42])
    #expect(reader.readFixedString(count: 4) == "AB")
    #expect(reader.readFixedString(count: 3, terminator: 0x40) == "A")
    #expect(reader.readFixedString(count: 3) == "A")
    #expect(reader.remainingCount == 0)
  }

  @Test func fixedStringPastEndDoesNotMove() {
    var reader = MessageReader([0x41, 0x42])
    #expect(reader.readFixedString(count: 3) == nil)
    #expect(reader.index == 0)
  }

  @Test(
    "Reads variable strings",
    arguments: [
      ([UInt8]([0x04, 0x01, 0x48, 0x69]), "Hi"),
      ([0x02, 0x01], ""),
      ([0x02, 0x00], ""),
      ([0x04, 0x00, 0xe9, 0x00], "é"),
      ([0x04, 0x00, 0xac, 0x20], "€"),
      ([0x06, 0x00, 0x61, 0x00, 0x00, 0x00], "a"),
      ([0x05, 0x01, 0x48, 0x69, 0xff], "Hi"),
      // Declared length runs past the payload: truncated, as upstream does.
      ([0x0a, 0x01, 0x48, 0x69], "Hi"),
    ])
  func readsVariableString(bytes: [UInt8], expected: String) {
    var reader = MessageReader(bytes)
    #expect(reader.readVariableString() == expected)
    #expect(reader.remainingCount == 0)
  }

  @Test func variableStringUCS2DropsTerminator() {
    var reader = MessageReader([0x08, 0x00, 0x41, 0x00, 0x40, 0x00, 0x42, 0x00])
    #expect(reader.readVariableString(terminator: 0x40) == "AB")
  }

  @Test(
    "Rejects invalid variable string headers",
    arguments: [
      [UInt8]([0xff, 0x01, 0x41]), [0x01, 0x01, 0x41], [0x03, 0x02, 0x41], [0x03, 0x01],
    ])
  func rejectsInvalidVariableString(bytes: [UInt8]) {
    var reader = MessageReader(bytes)
    #expect(reader.readVariableString() == nil)
    // Upstream skips the rest of the payload after an invalid header.
    #expect(reader.remainingCount == 0)
  }

  @Test func variableStringRoundTrips() {
    for string in ["", "Hello", "Café", "€100"] {
      var writer = MessageWriter()
      writer.appendVariableString(string)
      var reader = MessageReader(writer.data)
      #expect(reader.readVariableString() == string)
    }
  }

  @Test func readsBytes() {
    var reader = MessageReader([1, 2, 3])
    #expect(reader.readBytes(count: 2) == [1, 2])
    #expect(reader.readBytes(count: 2) == nil)
    #expect(reader.remainingCount == 0)
  }

  @Test func readsMessagePayload() {
    let message = Message(pgn: 129025, priority: 2, data: [0x87, 0x1c, 0xd6, 0x23])
    var reader = MessageReader(message)
    let latitude = reader.readInt32(resolution: 1e-7)
    #expect(latitude.map { abs($0 - 60.1234567) < 1e-9 } == true)
  }

  @Test func readsZeroLengthFields() {
    var reader = MessageReader(Message(pgn: 1, data: [1, 2]))
    #expect(reader.readFixedString(count: 0) == "")
    #expect(reader.readBytes(count: 0) == [])
    #expect(reader.readUInt8() == 1)
  }

  @Test func readsExactlyToTheEnd() {
    var reader = MessageReader(Message(pgn: 1, data: [0x41, 0x42, 3, 4]))
    #expect(reader.readFixedString(count: 2) == "AB")
    #expect(reader.readBytes(count: 2) == [3, 4])
    #expect(reader.remainingCount == 0)
  }

  @Test func variableStringUCS2KeepsATerminatorFrom0x80() {
    // Only terminators below 0x80 are dropped from UCS-2 text.
    var reader = MessageReader(Message(pgn: 1, data: [0x06, 0x00, 0x80, 0x00, 0x41, 0x00]))
    #expect(reader.readVariableString(terminator: 0x80) == "\u{80}A")
  }
}

@Suite("Message")
struct MessageTests {
  @Test func usesUpstreamDefaults() {
    let message = Message(pgn: 59904)
    #expect(message.priority == 6)
    #expect(message.source == 15)
    #expect(message.destination == Message.broadcastAddress)
    #expect(!message.isTransportProtocol)
  }

  @Test func masksPriority() {
    #expect(Message(pgn: 1, priority: 0xff).priority == 7)
  }

  @Test func validity() {
    #expect(!Message(pgn: 0, data: [1]).isValid)
    #expect(!Message(pgn: 1).isValid)
    #expect(Message(pgn: 1, data: [1]).isValid)
  }
}
