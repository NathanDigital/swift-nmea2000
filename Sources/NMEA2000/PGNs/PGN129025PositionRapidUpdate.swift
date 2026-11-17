// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129025, position rapid update: a frequently sent latitude and longitude.
///
/// Ports `SetN2kPGN129025` / `ParseN2kPGN129025`.
public struct PositionRapidUpdate: ParameterGroup {
  public static let pgn: UInt32 = 129025
  public static let defaultPriority: UInt8 = 2

  /// The latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// Creates a position rapid update.
  ///
  /// - Parameters:
  ///   - latitude: The latitude, in degrees, positive north.
  ///   - longitude: The longitude, in degrees, positive east.
  public init(latitude: Double?, longitude: Double?) {
    self.latitude = latitude
    self.longitude = longitude
  }

  public init(decoding reader: inout MessageReader) {
    latitude = reader.readInt32(resolution: 1e-7)
    longitude = reader.readInt32(resolution: 1e-7)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendInt32(latitude, resolution: 1e-7)
    writer.appendInt32(longitude, resolution: 1e-7)
  }
}
