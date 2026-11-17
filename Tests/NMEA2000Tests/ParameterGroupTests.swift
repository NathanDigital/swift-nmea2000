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
          prn: 7, elevation: 0.5, azimuth: nil, signalToNoiseRatio: 40, rangeResiduals: nil,
          usageStatus: PRNUsageStatus(rawValue: 9))
      ])
    let data = try JSONEncoder().encode(satellites)
    #expect(try JSONDecoder().decode(GNSSSatellitesInView.self, from: data) == satellites)
  }
}
