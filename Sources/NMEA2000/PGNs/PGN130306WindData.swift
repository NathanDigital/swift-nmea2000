// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130306, wind data: wind speed and angle.
///
/// Ports `SetN2kPGN130306` / `ParseN2kPGN130306`.
public struct WindData: ParameterGroup {
  public static let pgn: UInt32 = 130306
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The wind speed, in meters per second, or `nil` if not available.
  public var windSpeed: Double?

  /// The wind angle, in radians, or `nil` if not available.
  public var windAngle: Double?

  /// What the wind speed and angle are referenced to.
  public var reference: WindReference

  /// Creates a wind data message.
  public init(
    sequenceID: UInt8?,
    windSpeed: Double?,
    windAngle: Double?,
    reference: WindReference
  ) {
    self.sequenceID = sequenceID
    self.windSpeed = windSpeed
    self.windAngle = windAngle
    self.reference = reference
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    windSpeed = reader.readUInt16(resolution: 0.01)
    windAngle = reader.readUInt16(resolution: 0.0001)
    reference = WindReference(rawValue: reader.readUInt8() & 0x07)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(windSpeed, resolution: 0.01)
    writer.appendUInt16(windAngle, resolution: 0.0001)
    writer.appendUInt8(reference.rawValue)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
