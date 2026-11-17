// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("PGN 60928 ISO Address Claim")
struct ISOAddressClaimTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN60928`.
  static let vectors: [(ISOAddressClaim, [UInt8])] = [
    // typical
    (
      ISOAddressClaim(
        name: DeviceName(
          uniqueNumber: 1, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25)),
      [0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]
    ),
    // every field
    (
      ISOAddressClaim(
        name: DeviceName(
          uniqueNumber: 0x12345, manufacturerCode: 0x2a5, deviceFunction: 0x91,
          deviceClass: 0x5a, deviceInstance: 0xb3, systemInstance: 0x0c, industryGroup: 0x5)),
      [0x45, 0x23, 0xa1, 0x54, 0xb3, 0x91, 0xb4, 0xdc]
    ),
    // zero
    (
      ISOAddressClaim(
        name: DeviceName(
          uniqueNumber: 0, manufacturerCode: 0, deviceFunction: 0, deviceClass: 0,
          deviceInstance: 0, systemInstance: 0, industryGroup: 0)),
      [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]
    ),
    // NAME
    (
      ISOAddressClaim(name: DeviceName(rawValue: 0x0123_4567_89ab_cdef)),
      [0xef, 0xcd, 0xab, 0x89, 0x67, 0x45, 0x23, 0x01]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: ISOAddressClaim, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  @Test("Decodes upstream bytes", arguments: vectors)
  func decodes(_ value: ISOAddressClaim, bytes: [UInt8]) throws {
    try expectDecodes(bytes, as: value)
  }

  @Test func masksFieldsToTheirWidths() {
    // upstream-vectors "PGN60928 fields at their limits"
    let name = DeviceName(
      uniqueNumber: 0xffff_ffff, manufacturerCode: 0xffff, deviceFunction: 0xff,
      deviceClass: 0xff, deviceInstance: 0xff, systemInstance: 0xff, industryGroup: 0xff)
    expectEncodes(
      ISOAddressClaim(name: name), as: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xfe, 0xff],
      priority: 6)
  }

  @Test func decodesAShortClaimAsAllOnes() throws {
    let claim = try ISOAddressClaim(
      Message(pgn: 60928, data: [0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32]))
    #expect(claim.name.rawValue == .max)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(ISOAddressClaim.self, from: Self.vectors[0].1)
  }
}

@Suite("Device NAME")
struct DeviceNameTests {
  @Test func readsEveryField() {
    // upstream-vectors "PGN60928 every field"
    let name = DeviceName(rawValue: 0xdcb4_91b3_54a1_2345)
    #expect(name.uniqueNumber == 0x12345)
    #expect(name.manufacturerCode == 0x2a5)
    #expect(name.deviceInstance == 0xb3)
    #expect(name.deviceInstanceLower == 0x3)
    #expect(name.deviceInstanceUpper == 0x16)
    #expect(name.deviceFunction == 0x91)
    #expect(name.deviceClass == 0x5a)
    #expect(name.systemInstance == 0xc)
    #expect(name.industryGroup == 0x5)
    #expect(name.isArbitraryAddressCapable)
  }

  @Test func settingAFieldLeavesTheOthers() {
    var name = DeviceName(rawValue: .max)
    name.uniqueNumber = 0
    #expect(name.rawValue == 0xffff_ffff_ffe0_0000)
    name = DeviceName(rawValue: .max)
    name.manufacturerCode = 0
    #expect(name.rawValue == 0xffff_ffff_001f_ffff)
    name = DeviceName(rawValue: .max)
    name.deviceInstanceLower = 0
    #expect(name.rawValue == 0xffff_fff8_ffff_ffff)
    name = DeviceName(rawValue: .max)
    name.deviceInstanceUpper = 0
    #expect(name.rawValue == 0xffff_ff07_ffff_ffff)
    name = DeviceName(rawValue: .max)
    name.deviceFunction = 0
    #expect(name.rawValue == 0xffff_00ff_ffff_ffff)
    name = DeviceName(rawValue: .max)
    name.deviceClass = 0
    #expect(name.rawValue == 0xff01_ffff_ffff_ffff)
    name = DeviceName(rawValue: .max)
    name.systemInstance = 0
    #expect(name.rawValue == 0xf0ff_ffff_ffff_ffff)
    name = DeviceName(rawValue: .max)
    name.isArbitraryAddressCapable = false
    #expect(name.rawValue == 0x7fff_ffff_ffff_ffff)
  }

  @Test func settingTheIndustryGroupMakesTheDeviceArbitraryAddressCapable() {
    // Upstream's SetIndustryGroup sets the bit too.
    var name = DeviceName(rawValue: 0)
    name.industryGroup = 4
    #expect(name.rawValue == 0xc000_0000_0000_0000)
  }

  @Test func defaultIsUpstreamsDefaultDevice() {
    // The NAME upstream's node claims with: upstream-vectors "Node open".
    #expect(DeviceName.default.rawValue == 0xc032_8200_ffc0_0001)
  }

  @Test func ordersByValue() {
    #expect(DeviceName(rawValue: 1) < DeviceName(rawValue: 2))
    #expect(!(DeviceName(rawValue: 2) < DeviceName(rawValue: 2)))
  }
}
