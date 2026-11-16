// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

/// One field write and the bytes upstream's `tN2kMsg` produces for it.
struct WriterVector: Sendable, CustomTestStringConvertible {
  let name: String
  let expected: [UInt8]
  let write: @Sendable (inout MessageWriter) -> Void

  init(
    _ name: String, _ expected: [UInt8], _ write: @escaping @Sendable (inout MessageWriter) -> Void
  ) {
    self.name = name
    self.expected = expected
    self.write = write
  }

  var testDescription: String { name }
}

@Suite("MessageWriter")
struct MessageWriterTests {
  static let vectors: [WriterVector] = [
    // AddByte, Add2ByteInt, Add2ByteUInt, Add3ByteInt, Add4ByteUInt, AddUInt64
    WriterVector("UInt8", [0xab]) { $0.appendUInt8(0xab) },
    WriterVector("Int16", [0xfe, 0xff]) { $0.appendInt16(-2) },
    WriterVector("UInt16", [0x34, 0x12]) { $0.appendUInt16(0x1234) },
    WriterVector("Int24 negative", [0xfe, 0xff, 0xff]) { $0.appendInt24(-2) },
    WriterVector("UInt32", [0x78, 0x56, 0x34, 0x12]) { $0.appendUInt32(0x1234_5678) },
    WriterVector("UInt64", [0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]) {
      $0.appendUInt64(0x0102_0304_0506_0708)
    },

    // Add1ByteDouble
    WriterVector("Int8 scaled", [0x64]) { $0.appendInt8(1.0, resolution: 0.01) },
    WriterVector("Int8 minimum", [0x80]) { $0.appendInt8(-128, resolution: 1) },
    WriterVector("Int8 not available", [0x7f]) { $0.appendInt8(nil, resolution: 1) },
    WriterVector("Int8 above range", [0x7e]) { $0.appendInt8(126, resolution: 1) },
    WriterVector("Int8 below range", [0x7e]) { $0.appendInt8(-129, resolution: 1) },

    // Add1ByteUDouble
    WriterVector("UInt8 scaled", [0xfa]) { $0.appendUInt8(2.5, resolution: 0.01) },
    WriterVector("UInt8 not available", [0xff]) { $0.appendUInt8(nil, resolution: 1) },
    WriterVector("UInt8 above range", [0xfe]) { $0.appendUInt8(254, resolution: 1) },
    WriterVector("UInt8 negative", [0xfe]) { $0.appendUInt8(-1, resolution: 1) },

    // Add2ByteDouble, including C round() semantics (half away from zero)
    WriterVector("Int16 scaled", [0x24, 0xfa]) { $0.appendInt16(-1.5, resolution: 0.001) },
    WriterVector("Int16 rounds 0.5 up", [0x01, 0x00]) { $0.appendInt16(0.5, resolution: 1) },
    WriterVector("Int16 rounds -0.5 down", [0xff, 0xff]) { $0.appendInt16(-0.5, resolution: 1) },
    WriterVector("Int16 rounds 2.5 away from zero", [0x03, 0x00]) {
      $0.appendInt16(2.5, resolution: 1)
    },
    WriterVector("Int16 largest", [0xfd, 0x7f]) { $0.appendInt16(32765, resolution: 1) },
    WriterVector("Int16 minimum", [0x00, 0x80]) { $0.appendInt16(-32768, resolution: 1) },
    WriterVector("Int16 not available", [0xff, 0x7f]) { $0.appendInt16(nil, resolution: 1) },
    WriterVector("Int16 above range", [0xfe, 0x7f]) { $0.appendInt16(32766, resolution: 1) },
    WriterVector("Int16 NaN", [0xfe, 0x7f]) { $0.appendInt16(.nan, resolution: 1) },

    // Add2ByteUDouble
    WriterVector("UInt16 scaled", [0xb8, 0x7a]) { $0.appendUInt16(3.14159, resolution: 1e-4) },
    WriterVector("UInt16 largest", [0xfd, 0xff]) { $0.appendUInt16(65533, resolution: 1) },
    WriterVector("UInt16 not available", [0xff, 0xff]) { $0.appendUInt16(nil, resolution: 1) },
    WriterVector("UInt16 above range", [0xfe, 0xff]) { $0.appendUInt16(65534, resolution: 1) },
    WriterVector("UInt16 negative", [0xfe, 0xff]) { $0.appendUInt16(-1, resolution: 1) },

    // Add3ByteDouble
    WriterVector("Int24 scaled negative", [0xff, 0xff, 0xff]) {
      $0.appendInt24(-0.01, resolution: 0.01)
    },
    WriterVector("Int24 minimum", [0x00, 0x00, 0x80]) {
      $0.appendInt24(-8_388_608, resolution: 1)
    },
    WriterVector("Int24 not available", [0xff, 0xff, 0x7f]) {
      $0.appendInt24(nil, resolution: 1)
    },
    WriterVector("Int24 above range", [0xfe, 0xff, 0x7f]) {
      $0.appendInt24(8_388_606, resolution: 1)
    },

    // Add3ByteUDouble
    WriterVector("UInt24 scaled", [0x56, 0x34, 0x12]) {
      $0.appendUInt24(0x12_3456, resolution: 1)
    },
    WriterVector("UInt24 not available", [0xff, 0xff, 0xff]) {
      $0.appendUInt24(nil, resolution: 1)
    },
    WriterVector("UInt24 above range", [0xfe, 0xff, 0xff]) {
      $0.appendUInt24(16_777_214, resolution: 1)
    },

    // Add4ByteDouble
    WriterVector("Int32 latitude", [0x87, 0x1c, 0xd6, 0x23]) {
      $0.appendInt32(60.1234567, resolution: 1e-7)
    },
    WriterVector("Int32 longitude", [0xb8, 0x4a, 0xdf, 0xa5]) {
      $0.appendInt32(-151.2093, resolution: 1e-7)
    },
    WriterVector("Int32 not available", [0xff, 0xff, 0xff, 0x7f]) {
      $0.appendInt32(nil, resolution: 1)
    },
    WriterVector("Int32 above range", [0xfe, 0xff, 0xff, 0x7f]) {
      $0.appendInt32(3e9, resolution: 1)
    },

    // Add4ByteUDouble
    WriterVector("UInt32 scaled", [0x3a, 0xe2, 0x01, 0x00]) {
      $0.appendUInt32(1234.5, resolution: 0.01)
    },
    WriterVector("UInt32 not available", [0xff, 0xff, 0xff, 0xff]) {
      $0.appendUInt32(nil, resolution: 1)
    },
    WriterVector("UInt32 negative", [0xfe, 0xff, 0xff, 0xff]) {
      $0.appendUInt32(-1, resolution: 1)
    },

    // Add8ByteDouble truncates toward zero rather than rounding
    WriterVector("Int64 latitude", [0x00, 0x86, 0xb8, 0x38, 0xa7, 0x03, 0x58, 0x08]) {
      $0.appendInt64(60.1234567, resolution: 1e-16)
    },
    WriterVector("Int64 truncates positive", [2, 0, 0, 0, 0, 0, 0, 0]) {
      $0.appendInt64(2.9, resolution: 1)
    },
    WriterVector("Int64 truncates negative", [0xfe, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]) {
      $0.appendInt64(-2.9, resolution: 1)
    },
    WriterVector("Int64 not available", [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f]) {
      $0.appendInt64(nil, resolution: 1)
    },

    // AddFloat
    WriterVector("Float32", [0x00, 0x00, 0xc0, 0x3f]) { $0.appendFloat32(1.5) },
    WriterVector("Float32 not available", [0xff, 0xff, 0xff, 0x7f]) { $0.appendFloat32(nil) },

    // AddStr
    WriterVector("Fixed string padded", [0x41, 0x42, 0x43, 0xff, 0xff]) {
      $0.appendFixedString("ABC", count: 5)
    },
    WriterVector("Fixed string zero padding", [0x41, 0x00]) {
      $0.appendFixedString("A", count: 2, padding: 0)
    },
    WriterVector("Fixed string truncated", [0x41, 0x42, 0x43]) {
      $0.appendFixedString("ABCDEF", count: 3)
    },
    WriterVector("Fixed string nil", [0xff, 0xff]) { $0.appendFixedString(nil, count: 2) },

    // AddAISStr: upper-cases, maps each non-ASCII UTF-8 byte to '?', pads with '@'
    WriterVector("AIS string", [0x41, 0x42, 0x43, 0x3f, 0x3f, 0x3f, 0x40, 0x40]) {
      $0.appendAISString("abc~é", count: 8)
    },
    WriterVector("AIS string truncated", [0x41, 0x42]) { $0.appendAISString("ABCD", count: 2) },

    // AddVarStr
    WriterVector("Variable string empty", [0x02, 0x01]) { $0.appendVariableString("") },
    WriterVector("Variable string nil", [0x02, 0x01]) { $0.appendVariableString(nil) },
    WriterVector("Variable string ASCII", [0x04, 0x01, 0x48, 0x69]) {
      $0.appendVariableString("Hi")
    },
    WriterVector("Variable string ASCII truncated", [0x03, 0x01, 0x48]) {
      $0.appendVariableString("Hi", maxLength: 1)
    },
    WriterVector("Variable string UCS-2", [0x04, 0x00, 0xe9, 0x00]) {
      $0.appendVariableString("é")
    },
    WriterVector("Variable string UCS-2 three-byte UTF-8", [0x04, 0x00, 0xac, 0x20]) {
      $0.appendVariableString("€")
    },
    WriterVector("Variable string UCS-2 outside BMP", [0x06, 0x00, 0x61, 0x00, 0x3f, 0x00]) {
      $0.appendVariableString("a😀")
    },
    WriterVector("Variable string forced ASCII", [0x04, 0x01, 0x3f, 0x61]) {
      $0.appendVariableString("éa", encoding: .asciiOnly)
    },
    // Upstream's UCS-2 conversion leaves the last two bytes of the limit unused.
    WriterVector("Variable string UCS-2 byte limit", [0x04, 0x00, 0xe9, 0x00]) {
      $0.appendVariableString("éé", maxLength: 4)
    },
    WriterVector("Variable string UCS-2 character limit", [0x04, 0x00, 0xe9, 0x00]) {
      $0.appendVariableString("ééé", maxLength: 2, lengthUnit: .characters)
    },
    WriterVector("Variable string stops at NUL", [0x03, 0x01, 0x41]) {
      $0.appendVariableString("A\0B")
    },

    // AddBuf
    WriterVector("Bytes", [0x01, 0x02, 0x03]) { $0.appendBytes([1, 2, 3]) },
  ]

  @Test("Encodes fields as upstream does", arguments: vectors)
  func encodes(_ vector: WriterVector) {
    var writer = MessageWriter()
    vector.write(&writer)
    #expect(writer.data == vector.expected)
  }

  @Test func countsAvailableBytes() {
    var writer = MessageWriter()
    #expect(writer.availableCount == Message.maxDataCount)
    writer.appendUInt32(0)
    #expect(writer.count == 4)
    #expect(writer.availableCount == Message.maxDataCount - 4)
  }

  @Test func truncatesBytesToCapacity() {
    var writer = MessageWriter()
    writer.appendBytes([UInt8](repeating: 0, count: 220))
    writer.appendBytes([1, 2, 3, 4, 5])
    #expect(writer.count == Message.maxDataCount)
    #expect(writer.data.suffix(3) == [1, 2, 3])
  }

  @Test func truncatesAISStringToCapacity() {
    var writer = MessageWriter()
    writer.appendBytes([UInt8](repeating: 0, count: 221))
    writer.appendAISString("A", count: 5)
    #expect(writer.data.suffix(2) == [0x41, 0x40])
  }

  @Test(
    "Variable string when the payload is nearly full",
    arguments: [(2, [UInt8]([2, 1])), (1, [1]), (0, [])])
  func variableStringNearCapacity(free: Int, expected: [UInt8]) {
    var writer = MessageWriter()
    writer.appendBytes([UInt8](repeating: 0, count: Message.maxDataCount - free))
    writer.appendVariableString("Hello")
    #expect(Array(writer.data.dropFirst(Message.maxDataCount - free)) == expected)
  }

  @Test func variableStringTruncatedToCapacity() {
    var writer = MessageWriter()
    writer.appendBytes([UInt8](repeating: 0, count: Message.maxDataCount - 4))
    writer.appendVariableString("Hello")
    #expect(Array(writer.data.suffix(4)) == [0x04, 0x01, 0x48, 0x65])
  }

  @Test func patchesEarlierFields() {
    var writer = MessageWriter()
    let countIndex = writer.count
    writer.appendUInt8(0)
    writer.appendUInt16(0)
    writer.setUInt8(3, at: countIndex)
    writer.setUInt16(0x1234, at: countIndex + 1)
    #expect(writer.data == [3, 0x34, 0x12])
  }
}
