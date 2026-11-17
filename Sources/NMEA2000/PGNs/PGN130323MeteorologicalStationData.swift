// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130323, meteorological station data.
///
/// Ports `SetN2kPGN130323` / `ParseN2kPGN130323`. Upstream's `tN2kMeteorlogicalStationData` becomes
/// this type's properties.
public struct MeteorologicalStationData: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 130323
  public static let defaultPriority: UInt8 = 6

  /// The longest station identifier upstream sends, in characters.
  public static let maxStationIDLength = 15

  /// The longest station name upstream sends, in characters.
  public static let maxStationNameLength = 50

  /// Whether the station is in autonomous or assigned mode.
  public var mode: AISMode

  /// The date of the observation, in days since 1970-01-01, or `nil` if not available.
  public var daysSince1970: UInt16?

  /// The time of the observation, in seconds since midnight UTC, or `nil` if not available.
  public var secondsSinceMidnight: Double?

  /// The station latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The station longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// The wind speed, in meters per second, or `nil` if not available.
  public var windSpeed: Double?

  /// The wind direction, in radians, or `nil` if not available.
  public var windDirection: Double?

  /// What the wind direction is referenced to.
  public var windReference: WindReference

  /// The wind gust speed, in meters per second, or `nil` if not available.
  public var windGusts: Double?

  /// The atmospheric pressure, in pascals, or `nil` if not available.
  public var atmosphericPressure: Double?

  /// The outside air temperature, in kelvins, or `nil` if not available.
  public var outsideAirTemperature: Double?

  /// The station identifier.
  ///
  /// Upstream stores it in a buffer of ``maxStationIDLength`` UTF-8 bytes, so at most that many bytes
  /// are sent.
  public var stationID: String

  /// The station name.
  ///
  /// Upstream stores it in a buffer of ``maxStationNameLength`` UTF-8 bytes, so at most that many bytes
  /// are sent.
  public var stationName: String

  /// Creates a meteorological station data message.
  ///
  /// The defaults match the initial values of upstream's `tN2kMeteorlogicalStationData`.
  public init(
    mode: AISMode = .autonomous,
    daysSince1970: UInt16? = nil,
    secondsSinceMidnight: Double? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    windSpeed: Double? = nil,
    windDirection: Double? = nil,
    windReference: WindReference = .unavailable,
    windGusts: Double? = nil,
    atmosphericPressure: Double? = nil,
    outsideAirTemperature: Double? = nil,
    stationID: String = "",
    stationName: String = ""
  ) {
    self.mode = mode
    self.daysSince1970 = daysSince1970
    self.secondsSinceMidnight = secondsSinceMidnight
    self.latitude = latitude
    self.longitude = longitude
    self.windSpeed = windSpeed
    self.windDirection = windDirection
    self.windReference = windReference
    self.windGusts = windGusts
    self.atmosphericPressure = atmosphericPressure
    self.outsideAirTemperature = outsideAirTemperature
    self.stationID = stationID
    self.stationName = stationName
  }

  public init(from reader: inout MessageReader) {
    mode = AISMode(rawValue: reader.readUInt8() & 0x0f)
    daysSince1970 = reader.readOptionalUInt16()
    secondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
    latitude = reader.readInt32(resolution: 1e-7)
    longitude = reader.readInt32(resolution: 1e-7)
    windSpeed = reader.readUInt16(resolution: 0.01)
    windDirection = reader.readUInt16(resolution: 0.0001)
    windReference = WindReference(rawValue: reader.readUInt8() & 0x07)
    windGusts = reader.readUInt16(resolution: 0.01)
    atmosphericPressure = reader.readUInt16(resolution: 100)
    outsideAirTemperature = reader.readUInt16(resolution: 0.01)
    stationID = reader.readVariableString() ?? ""
    stationName = reader.readVariableString() ?? ""
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(mode.rawValue & 0x0f | 0xf0)
    writer.appendUInt16(daysSince1970)
    writer.appendUInt32(secondsSinceMidnight, resolution: 0.0001)
    writer.appendInt32(latitude, resolution: 1e-7)
    writer.appendInt32(longitude, resolution: 1e-7)
    writer.appendUInt16(windSpeed, resolution: 0.01)
    writer.appendUInt16(windDirection, resolution: 0.0001)
    writer.appendUInt8(windReference.rawValue & 0x07 | 0xf8)
    writer.appendUInt16(windGusts, resolution: 0.01)
    writer.appendUInt16(atmosphericPressure, resolution: 100)
    writer.appendUInt16(outsideAirTemperature, resolution: 0.01)
    // Upstream holds both strings in fixed byte buffers before encoding them.
    writer.appendVariableString(
      stationID.prefix(utf8ByteCount: Self.maxStationIDLength),
      maxLength: Self.maxStationIDLength, encoding: .unicode, lengthUnit: .characters)
    writer.appendVariableString(
      stationName.prefix(utf8ByteCount: Self.maxStationNameLength),
      maxLength: Self.maxStationNameLength, encoding: .unicode, lengthUnit: .characters)
  }
}
