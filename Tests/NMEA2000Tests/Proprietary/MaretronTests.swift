// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("Maretron PGNs")
struct MaretronTests {
  /// Values and the bytes upstream's encoders produce for them, from
  /// `scripts/upstream-vectors Maretron`.
  static let temperatures: [(MaretronTemperatureHighRange, [UInt8])] = [
    (
      MaretronTemperatureHighRange(
        sequenceID: 1, instance: 2, source: .exhaustGas, actualTemperature: 873.15,
        setTemperature: 300.05),
      [0x89, 0x98, 0x01, 0x02, 0x0e, 0x1c, 0x22, 0xb9, 0x0b]
    ),
    (
      MaretronTemperatureHighRange(
        sequenceID: nil, instance: 0xfe, source: TemperatureSource(rawValue: 0xab),
        actualTemperature: nil, setTemperature: 6553.4),
      [0x89, 0x98, 0xff, 0xfe, 0xab, 0xff, 0xff, 0xfe, 0xff]
    ),
  ]

  static let flowRates: [(MaretronFluidFlowRate, [UInt8])] = [
    (
      MaretronFluidFlowRate(sequenceID: 3, instance: 1, fluidType: .fuel, flowRate: 12.3),
      [0x89, 0x98, 0x03, 0x01, 0x00, 0x7b, 0x00, 0x00]
    ),
    (
      MaretronFluidFlowRate(
        sequenceID: nil, instance: 0xff, fluidType: FluidType(rawValue: 0x0e),
        flowRate: -838860.7),
      [0x89, 0x98, 0xff, 0xff, 0x0e, 0x01, 0x00, 0x80]
    ),
    (
      MaretronFluidFlowRate(sequenceID: 0, instance: 0, fluidType: .water, flowRate: nil),
      [0x89, 0x98, 0x00, 0x00, 0x01, 0xff, 0xff, 0x7f]
    ),
  ]

  static let volumes: [(MaretronTripVolume, [UInt8])] = [
    (
      MaretronTripVolume(sequenceID: 4, instance: 2, fluidType: .fuel, volume: 1_234_567),
      [0x89, 0x98, 0x04, 0x02, 0x00, 0x87, 0xd6, 0x12]
    ),
    (
      MaretronTripVolume(sequenceID: nil, instance: 0xff, fluidType: .oil, volume: nil),
      [0x89, 0x98, 0xff, 0xff, 0x04, 0xff, 0xff, 0x7f]
    ),
  ]

  @Test("Temperature encodes and decodes as upstream does", arguments: temperatures)
  func temperature(_ value: MaretronTemperatureHighRange, bytes: [UInt8]) throws {
    expectEncodes(value, as: bytes, priority: 5)
    try expectDecodes(bytes, as: value)
  }

  @Test("Flow rate encodes and decodes as upstream does", arguments: flowRates)
  func flowRate(_ value: MaretronFluidFlowRate, bytes: [UInt8]) throws {
    expectEncodes(value, as: bytes, priority: 5)
    try expectDecodes(bytes, as: value)
  }

  @Test("Trip volume encodes and decodes as upstream does", arguments: volumes)
  func tripVolume(_ value: MaretronTripVolume, bytes: [UInt8]) throws {
    expectEncodes(value, as: bytes, priority: 5)
    try expectDecodes(bytes, as: value)
  }

  @Test func sendsOutOfRangeTemperatures() {
    // upstream-vectors "Maretron 130823", third message.
    expectEncodes(
      MaretronTemperatureHighRange(
        sequenceID: 0, instance: 0, source: .sea, actualTemperature: 6553.5, setTemperature: -1),
      as: [0x89, 0x98, 0x00, 0x00, 0x00, 0xfe, 0xff, 0xfe, 0xff], priority: 5)
  }

  @Test func rejectsMessagesWithoutMaretronsHeader() {
    #expect(throws: MessageDecodingError.self) {
      _ = try MaretronTemperatureHighRange(
        Message(pgn: 130823, data: [0x89, 0x99, 1, 2, 0, 0, 0, 0, 0]))
    }
    #expect(throws: MessageDecodingError.self) {
      _ = try MaretronFluidFlowRate(Message(pgn: 65286, data: [0x88, 0x98, 1, 2, 0, 0, 0, 0]))
    }
    #expect(throws: MessageDecodingError.self) {
      _ = try MaretronTripVolume(Message(pgn: 65287, data: []))
    }
    #expect(throws: MessageDecodingError.self) {
      _ = try MaretronTripVolume(Message(pgn: 65286, data: Self.volumes[0].1))
    }
  }

  @Test func toleratesShortPayloadsAfterTheHeader() throws {
    let volume = try MaretronTripVolume(Message(pgn: 65287, data: [0x89, 0x98, 4]))
    #expect(volume.sequenceID == 4)
    #expect(volume.volume == nil)
  }
}
