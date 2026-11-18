// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import Foundation
import NMEA2000
import Testing

@Suite("Parameter groups")
struct ParameterGroupTests {
  @Test func roundTripsThroughJSON() throws {
    let satellites = GNSSSatellitesInView(
      sequenceID: 1, mode: .calculatedAfterPosition,
      satellites: [
        .init(
          usageStatus: PRNUsageStatus(rawValue: 9), prn: 7, elevation: 0.5, azimuth: nil,
          signalToNoiseRatio: 40,
          rangeResidual: nil)
      ])
    let data = try JSONEncoder().encode(satellites)
    #expect(try JSONDecoder().decode(GNSSSatellitesInView.self, from: data) == satellites)
  }

  @Test func catalogsEveryStandardParameterGroupByItsOwnPGN() {
    // Each type has its own PGN, so none replaced another.
    #expect(ParameterGroupCatalog.standard.pgns.count == 65)
    for pgn in ParameterGroupCatalog.standard.pgns {
      #expect(ParameterGroupCatalog.standard[pgn: pgn]?.pgn == pgn)
    }
  }

  @Test func decodesWithTheTypeForThePGN() throws {
    let message = PositionRapidUpdate(latitude: 60.5, longitude: 24.25).makeMessage()
    let decoded = try #require(try message.decoded())
    #expect(
      decoded as? PositionRapidUpdate == PositionRapidUpdate(latitude: 60.5, longitude: 24.25))
    #expect(try Message(pgn: 65286, data: [0x89, 0x98, 1, 2, 3]).decoded() == nil)
    var catalog = ParameterGroupCatalog.standard
    catalog.add(ParameterGroupCatalog.maretron)
    let flow = try Message(pgn: 65286, data: [0x89, 0x98, 1, 2, 3]).decoded(using: catalog)
    #expect(flow is MaretronFluidFlowRate)
    let combined = ParameterGroupCatalog.standard.adding(.maretron)
    #expect(combined.pgns.count == catalog.pgns.count)
    #expect(try Message(pgn: 65286, data: [0x89, 0x98, 1, 2, 3]).decoded(using: combined) != nil)
  }
}
