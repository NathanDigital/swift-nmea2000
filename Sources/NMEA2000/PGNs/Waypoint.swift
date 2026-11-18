// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A named waypoint in a route or waypoint list.
///
/// Used by ``RouteWaypointInformation`` (PGN 129285) and ``WaypointList``
/// (PGN 130074). Ports the arguments of upstream's `AppendN2kPGN129285` and
/// `AppendN2kPGN130074`.
public struct Waypoint: Sendable, Codable, Hashable {
  /// The waypoint's identifier.
  public var id: UInt16

  /// The waypoint's name.
  public var name: String

  /// The latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// Creates a waypoint.
  public init(id: UInt16, name: String, latitude: Double? = nil, longitude: Double? = nil) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
  }
}
