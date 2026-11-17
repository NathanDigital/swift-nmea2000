// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

/// A NAME with manufacturer 2046 and a unique number.
private func name(_ unique: UInt32) -> DeviceName {
  DeviceName(rawValue: 0xc032_8200_ffc0_0000 | UInt64(unique))
}

/// A list holding devices at 0x10 (unique 1) and 0x20 (unique 2), both with
/// product code 77, and 0x30 (unique 3) with product code 88.
private func makeList() -> DeviceList {
  var list = DeviceList()
  let devices: [(UInt8, UInt32, UInt16)] = [(0x10, 1, 77), (0x20, 2, 77), (0x30, 3, 88)]
  for (source, unique, product) in devices {
    list.handle(
      Message(
        pgn: 60928, source: source, data: ISOAddressClaim(name: name(unique)).makeMessage().data),
      at: 0, sending: { _ in true })
    var information = ProductInformation.default
    information.productCode = product
    list.handle(
      Message(pgn: 126996, source: source, data: information.makeMessage().data), at: 0,
      sending: { _ in true })
  }
  return list
}

@Suite("Device list")
struct DeviceListTests {
  @Test func findsDevicesByAddressAndName() {
    let list = makeList()
    #expect(list.count == 3)
    #expect(list.devices.map(\.source) == [0x10, 0x20, 0x30])
    #expect(list[source: 0x20]?.name == name(2))
    #expect(list[source: 0x21] == nil)
    #expect(list[source: 255] == nil)
    #expect(list.device(named: name(3))?.source == 0x30)
    #expect(list.device(named: name(4)) == nil)
  }

  @Test func findsDevicesByIdentifiers() {
    let list = makeList()
    #expect(list.device(manufacturerCode: 2046, uniqueNumber: 2)?.source == 0x20)
    #expect(list.device(manufacturerCode: nil, uniqueNumber: 3)?.source == 0x30)
    #expect(list.device(manufacturerCode: 2046, uniqueNumber: nil)?.source == 0x10)
    #expect(list.device(manufacturerCode: 100, uniqueNumber: nil) == nil)
    #expect(list.device(manufacturerCode: nil, uniqueNumber: nil) == nil)
  }

  @Test func findsDevicesByProductOneAfterAnother() {
    let list = makeList()
    let first = list.device(manufacturerCode: 2046, productCode: 77)
    #expect(first?.source == 0x10)
    let second = list.device(manufacturerCode: 2046, productCode: 77, after: first?.source)
    #expect(second?.source == 0x20)
    #expect(list.device(manufacturerCode: 2046, productCode: 77, after: second?.source) == nil)
    #expect(list.device(manufacturerCode: 2046, productCode: 88)?.source == 0x30)
    #expect(list.device(manufacturerCode: 2046, productCode: 77, after: 0x30) == nil)
  }

  @Test func reportsUpdatesOnce() {
    var list = makeList()
    #expect(list.isUpdated)
    let first = list.resetUpdated()
    let second = list.resetUpdated()
    #expect(first)
    #expect(!second)
    #expect(!list.isUpdated)
  }

  @Test func recordsWhenADeviceWasLastHeard() {
    var list = makeList()
    list.handle(Message(pgn: 130306, source: 0x20, data: [1]), at: 1234, sending: { _ in true })
    #expect(list[source: 0x20]?.lastMessageTime == 1234)
  }

  @Test func ignoresConfigurationInformationThatDoesNotParse() {
    var list = makeList()
    list.handle(
      Message(pgn: 126998, source: 0x10, data: [0x05, 0x07, 0x41]), at: 0, sending: { _ in true })
    #expect(list[source: 0x10]?.configurationInformation == nil)
  }

  @Test func keepsTheProductInformationOnceLoaded() {
    var list = makeList()
    _ = list.resetUpdated()
    var other = ProductInformation.default
    other.productCode = 99
    list.handle(
      Message(pgn: 126996, source: 0x10, data: other.makeMessage().data), at: 0,
      sending: { _ in true })
    #expect(list[source: 0x10]?.productInformation?.productCode == 77)
    #expect(!list.isUpdated)
  }
}
