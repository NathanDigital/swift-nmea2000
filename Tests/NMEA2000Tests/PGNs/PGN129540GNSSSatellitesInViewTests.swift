// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

/// The satellites upstream's harness appends, more than fit in one message.
private let manySatellites: [GNSSSatellitesInView.Satellite] = (0..<20).map { i in
  // Spelled out with explicit types to keep type-checking fast on slower CI machines.
  let x = Double(i)
  return GNSSSatellitesInView.Satellite(
    usageStatus: .trackedNotUsed, prn: UInt8(i + 1), elevation: 0.1 * x, azimuth: 0.2 * x,
    signalToNoiseRatio: 30.0 + x, rangeResidual: 0.01 * x)
}

@Suite("PGN 129540 GNSSSatellitesInView")
struct GNSSSatellitesInViewTests {
  /// Values and the bytes upstream's encoder produces for them, from
  /// `scripts/upstream-vectors PGN129540`.
  static let vectors: [(GNSSSatellitesInView, [UInt8])] = [
    // two satellites
    (
      GNSSSatellitesInView(
        sequenceID: 14, mode: .calculatedAfterPosition,
        satellites: [
          .init(
            usageStatus: .usedWithoutDifferentialCorrections, prn: 5, elevation: 0.5, azimuth: 2.5,
            signalToNoiseRatio: 42.25,
            rangeResidual: -1.5),
          .init(
            usageStatus: .unavailable, prn: nil, elevation: nil, azimuth: nil,
            signalToNoiseRatio: nil,
            rangeResidual: nil),
        ]),
      [
        0x0e, 0xfd, 0x02, 0x05, 0x88, 0x13, 0xa8, 0x61, 0x81, 0x10, 0x10, 0xb6, 0xfd, 0xff, 0xf2,
        0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xff,
      ]
    ),
    // more than the limit
    (
      GNSSSatellitesInView(sequenceID: 15, mode: .unavailable, satellites: manySatellites),
      [
        0x0f, 0xff, 0x12, 0x01, 0x00, 0x00, 0x00, 0x00, 0xb8, 0x0b, 0x00, 0x00, 0x00, 0x00, 0xf1,
        0x02, 0xe8, 0x03, 0xd0, 0x07, 0x1c, 0x0c, 0xe8, 0x03, 0x00, 0x00, 0xf1, 0x03, 0xd0, 0x07,
        0xa0, 0x0f, 0x80, 0x0c, 0xd0, 0x07, 0x00, 0x00, 0xf1, 0x04, 0xb8, 0x0b, 0x70, 0x17, 0xe4,
        0x0c, 0xb8, 0x0b, 0x00, 0x00, 0xf1, 0x05, 0xa0, 0x0f, 0x40, 0x1f, 0x48, 0x0d, 0xa0, 0x0f,
        0x00, 0x00, 0xf1, 0x06, 0x88, 0x13, 0x10, 0x27, 0xac, 0x0d, 0x88, 0x13, 0x00, 0x00, 0xf1,
        0x07, 0x70, 0x17, 0xe0, 0x2e, 0x10, 0x0e, 0x70, 0x17, 0x00, 0x00, 0xf1, 0x08, 0x58, 0x1b,
        0xb0, 0x36, 0x74, 0x0e, 0x58, 0x1b, 0x00, 0x00, 0xf1, 0x09, 0x40, 0x1f, 0x80, 0x3e, 0xd8,
        0x0e, 0x40, 0x1f, 0x00, 0x00, 0xf1, 0x0a, 0x28, 0x23, 0x50, 0x46, 0x3c, 0x0f, 0x28, 0x23,
        0x00, 0x00, 0xf1, 0x0b, 0x10, 0x27, 0x20, 0x4e, 0xa0, 0x0f, 0x10, 0x27, 0x00, 0x00, 0xf1,
        0x0c, 0xf8, 0x2a, 0xf0, 0x55, 0x04, 0x10, 0xf8, 0x2a, 0x00, 0x00, 0xf1, 0x0d, 0xe0, 0x2e,
        0xc0, 0x5d, 0x68, 0x10, 0xe0, 0x2e, 0x00, 0x00, 0xf1, 0x0e, 0xc8, 0x32, 0x90, 0x65, 0xcc,
        0x10, 0xc8, 0x32, 0x00, 0x00, 0xf1, 0x0f, 0xb0, 0x36, 0x60, 0x6d, 0x30, 0x11, 0xb0, 0x36,
        0x00, 0x00, 0xf1, 0x10, 0x98, 0x3a, 0x30, 0x75, 0x94, 0x11, 0x98, 0x3a, 0x00, 0x00, 0xf1,
        0x11, 0x80, 0x3e, 0x00, 0x7d, 0xf8, 0x11, 0x80, 0x3e, 0x00, 0x00, 0xf1, 0x12, 0x68, 0x42,
        0xd0, 0x84, 0x5c, 0x12, 0x68, 0x42, 0x00, 0x00, 0xf1,
      ]
    ),
    // defaults
    (
      GNSSSatellitesInView(),
      [0xff, 0xff, 0x00]
    ),
  ]

  @Test("Encodes as upstream does", arguments: vectors)
  func encodes(_ value: GNSSSatellitesInView, bytes: [UInt8]) {
    expectEncodes(value, as: bytes, priority: 6)
  }

  /// What the vectors that encoding changes decode to, by index in `vectors`.
  static let decodedValues: [Int: GNSSSatellitesInView] = [
    // Satellites past the 18 that fit are dropped.
    1: with(vectors[1].0) { $0.satellites = Array($0.satellites.prefix(18)) }
  ]

  @Test("Decodes upstream bytes", arguments: vectors.indices)
  func decodes(index: Int) throws {
    let (value, bytes) = Self.vectors[index]
    try expectDecodes(bytes, as: Self.decodedValues[index] ?? value)
  }

  @Test func toleratesShortPayloadsAndRejectsOtherPGNs() {
    expectTolerantDecoding(GNSSSatellitesInView.self, from: Self.vectors[0].1)
  }

  @Test func decodesMoreSatellitesThanUpstreamParses() throws {
    // Upstream's header parser still returns the SID, mode and count; its
    // per-satellite parser refuses every satellite past 18 declared.
    let satellite: [UInt8] = [7, 0x10, 0x27, 0x20, 0x4e, 0xe8, 0x03, 0x01, 0x00, 0x00, 0x00, 0xf2]
    let data = [0x01, 0xfc, 19] + Array([[UInt8]](repeating: satellite, count: 19).joined())
    let decoded = try GNSSSatellitesInView(Message(pgn: 129540, data: data))
    #expect(decoded.sequenceID == 1)
    #expect(decoded.satellites.count == 19)
    #expect(decoded.satellites.allSatisfy { $0.prn == 7 && $0.usageStatus.rawValue == 2 })
    // Only 18 go back out.
    #expect(decoded.makeMessage().data == [0x01, 0xfc, 18] + data[3..<(3 + 18 * 12)])
  }

  @Test func saysHowManySatellitesAreSent() throws {
    var satellites = GNSSSatellitesInView()
    let satellite = GNSSSatellitesInView.Satellite(
      usageStatus: PRNUsageStatus(rawValue: 0), prn: 1, elevation: nil, azimuth: nil,
      signalToNoiseRatio: nil,
      rangeResidual: nil)
    satellites.satellites = Array(repeating: satellite, count: 5)
    #expect(satellites.sentSatelliteCount == 5)
    satellites.satellites = Array(repeating: satellite, count: 20)
    #expect(satellites.sentSatelliteCount == 18)
  }
}
