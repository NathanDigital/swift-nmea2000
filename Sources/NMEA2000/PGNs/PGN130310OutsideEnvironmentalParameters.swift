// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130310, environmental parameters: water and air temperature and pressure.
///
/// Ports `SetN2kPGN130310` / `ParseN2kPGN130310`.
public struct OutsideEnvironmentalParameters: ParameterGroup {
  public static let pgn: UInt32 = 130310
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The water temperature, in kelvins, or `nil` if not available.
  public var waterTemperature: Double?

  /// The outside air temperature, in kelvins, or `nil` if not available.
  public var outsideAirTemperature: Double?

  /// The atmospheric pressure, in pascals, or `nil` if not available.
  public var atmosphericPressure: Double?

  /// Creates an outside environmental parameters message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kPGN130310`.
  public init(
    sequenceID: UInt8? = nil,
    waterTemperature: Double? = nil,
    outsideAirTemperature: Double? = nil,
    atmosphericPressure: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.waterTemperature = waterTemperature
    self.outsideAirTemperature = outsideAirTemperature
    self.atmosphericPressure = atmosphericPressure
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    waterTemperature = reader.readUInt16(resolution: 0.01)
    outsideAirTemperature = reader.readUInt16(resolution: 0.01)
    atmosphericPressure = reader.readUInt16(resolution: 100)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(waterTemperature, resolution: 0.01)
    writer.appendUInt16(outsideAirTemperature, resolution: 0.01)
    writer.appendUInt16(atmosphericPressure, resolution: 100)
    writer.appendUInt8(0xff)
  }
}
