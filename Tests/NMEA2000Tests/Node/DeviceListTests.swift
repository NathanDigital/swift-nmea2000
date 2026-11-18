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

/// A list holding devices at 0x10 (unique 1) and 0x11 (unique 2), both with
/// product code 77, and 0x30 (unique 3) with product code 88.
private func makeList() -> DeviceList {
  var list = DeviceList()
  let devices: [(UInt8, UInt32, UInt16)] = [(0x10, 1, 77), (0x11, 2, 77), (0x30, 3, 88)]
  for (source, unique, product) in devices {
    list.handle(
      Message(
        pgn: 60928, source: source, data: ISOAddressClaim(name: name(unique)).makeMessage().data),
      at: .milliseconds(0), sending: { _ in true })
    var information = ProductInformation.default
    information.productCode = product
    list.handle(
      Message(pgn: 126996, source: source, data: information.makeMessage().data),
      at: .milliseconds(0),
      sending: { _ in true })
  }
  return list
}

@Suite("Device list")
struct DeviceListTests {
  @Test func findsDevicesByAddressAndName() {
    let list = makeList()
    #expect(list.count == 3)
    #expect(list.devices.map(\.address) == [0x10, 0x11, 0x30])
    #expect(list[address: 0x11]?.name == name(2))
    #expect(list[address: 0x21] == nil)
    #expect(list[address: 254] == nil)
    #expect(list[address: 255] == nil)
    #expect(list.device(named: name(3))?.address == 0x30)
    #expect(list.device(named: name(4)) == nil)
  }

  @Test func findsDevicesByIdentifiers() {
    let list = makeList()
    #expect(list.device(manufacturerCode: 2046, uniqueNumber: 2)?.address == 0x11)
    #expect(list.device(manufacturerCode: nil, uniqueNumber: 3)?.address == 0x30)
    #expect(list.device(manufacturerCode: 2046, uniqueNumber: nil)?.address == 0x10)
    #expect(list.device(manufacturerCode: 100, uniqueNumber: nil) == nil)
    #expect(list.device(manufacturerCode: nil, uniqueNumber: nil) == nil)
  }

  @Test func findsDevicesByProductOneAfterAnother() {
    let list = makeList()
    let first = list.device(manufacturerCode: 2046, productCode: 77)
    #expect(first?.address == 0x10)
    let second = list.device(manufacturerCode: 2046, productCode: 77, after: first?.address)
    #expect(second?.address == 0x11)
    #expect(list.device(manufacturerCode: 2046, productCode: 77, after: second?.address) == nil)
    #expect(list.device(manufacturerCode: 2046, productCode: 88)?.address == 0x30)
    #expect(list.device(manufacturerCode: 2046, productCode: 77, after: 0x30) == nil)
    // Past the last address, the search starts again from the first.
    #expect(list.device(manufacturerCode: 2046, productCode: 77, after: 0x31)?.address == 0x10)
  }

  @Test func reportsChanges() {
    var list = DeviceList()
    let claim = Message(
      pgn: 60928, source: 0x10, data: ISOAddressClaim(name: name(1)).makeMessage().data)
    let first = list.handle(claim, at: .milliseconds(0), sending: { _ in true })
    let second = list.handle(claim, at: .milliseconds(0), sending: { _ in true })
    #expect(first)
    #expect(!second)
  }

  @Test func entriesCompareByWhatTheyReport() {
    var list = makeList()
    list.handle(
      Message(pgn: 130306, source: 0x10, data: [1]), at: .milliseconds(2000),
      sending: { _ in true })
    let before = list[address: 0x10]
    // A message from another device makes the list ask 0x10 again, which
    // changes only the list's own record of its requests to 0x10.
    var asked: [UInt8] = []
    list.handle(
      Message(pgn: 130306, source: 0x11, data: [1]), at: .milliseconds(3500),
      sending: { request in
        asked.append(request.destination)
        return true
      })
    #expect(asked == [0x10])
    #expect(list[address: 0x10] == before)
    #expect(list[address: 0x10]?.hashValue == before?.hashValue)
    #expect(list[address: 0x10] != list[address: 0x11])
  }

  @Test func ignoresAddressesNoDeviceCanHold() {
    var list = makeList()
    var requests = 0
    list.handle(
      Message(pgn: 130306, source: 254, data: [1]), at: .milliseconds(0),
      sending: { _ in
        requests += 1
        return true
      })
    #expect(list.count == 3)
    #expect(requests == 0)
  }

  @Test func recordsWhenADeviceWasLastHeard() {
    var list = makeList()
    list.handle(
      Message(pgn: 130306, source: 0x11, data: [1]), at: .milliseconds(1234), sending: { _ in true }
    )
    #expect(list[address: 0x11]?.lastMessageTime == .milliseconds(1234))
  }

  @Test func ignoresConfigurationInformationThatDoesNotParse() {
    var list = makeList()
    list.handle(
      Message(pgn: 126998, source: 0x10, data: [0x05, 0x07, 0x41]), at: .milliseconds(0),
      sending: { _ in true })
    #expect(list[address: 0x10]?.configurationInformation == nil)
  }

  @Test func keepsTheProductInformationOnceLoaded() {
    var list = makeList()
    var other = ProductInformation.default
    other.productCode = 99
    let isChanged = list.handle(
      Message(pgn: 126996, source: 0x10, data: other.makeMessage().data), at: .milliseconds(0),
      sending: { _ in true })
    #expect(list[address: 0x10]?.productInformation?.productCode == 77)
    #expect(!isChanged)
  }
}
