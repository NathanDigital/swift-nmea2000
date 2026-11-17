// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 126998 Configuration Information")
struct ConfigurationInformationTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN126998`.
  static let vectors: [(ConfigurationInformation, [UInt8])] = [
    // typical
    (
      ConfigurationInformation(
        manufacturerInformation: "Kave Oy", installationDescription1: "Mast head",
        installationDescription2: "Starboard side"),
      [
        0x0b, 0x01, 0x4d, 0x61, 0x73, 0x74, 0x20, 0x68, 0x65, 0x61, 0x64, 0x10, 0x01, 0x53, 0x74,
        0x61, 0x72, 0x62, 0x6f, 0x61, 0x72, 0x64, 0x20, 0x73, 0x69, 0x64, 0x65, 0x09, 0x01, 0x4b,
        0x61, 0x76, 0x65, 0x20, 0x4f, 0x79,
      ]
    ),
    // empty
    (
      ConfigurationInformation(
        manufacturerInformation: "", installationDescription1: "",
        installationDescription2: ""),
      [0x02, 0x01, 0x02, 0x01, 0x02, 0x01]
    ),
    // unicode and long
    (
      ConfigurationInformation(
        manufacturerInformation:
          "0123456789012345678901234567890123456789012345678901234567890123456789XYZ",
        installationDescription1: "Båt", installationDescription2: "a"),
      [
        0x08, 0x00, 0x42, 0x00, 0xe5, 0x00, 0x74, 0x00, 0x03, 0x01, 0x61, 0x49, 0x01, 0x30, 0x31,
        0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
        0x37, 0x38, 0x39, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30, 0x31,
        0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
        0x37, 0x38, 0x39, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30, 0x31,
        0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x58,
      ]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ConfigurationInformation, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  static let decodedValues: [Int: ConfigurationInformation] = [
    // Fields are cut to 71 bytes.
    2: with(vectors[2].0) {
      $0.manufacturerInformation = String($0.manufacturerInformation.prefix(71))
    }
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ConfigurationInformation.self, from: Self.vectors[0].1)
  }
}
