// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127497, trip parameters, engine.
///
/// Ports `SetN2kPGN127497` / `ParseN2kPGN127497`.
public struct EngineTripParameters: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127497
  public static let defaultPriority: UInt8 = 2

  /// The engine instance.
  public var instance: UInt8

  /// The fuel used this trip, in litres (as upstream uses), or `nil` if not available.
  public var tripFuelUsed: Double?

  /// The average fuel rate, in litres per hour, or `nil` if not available.
  public var fuelRateAverage: Double?

  /// The economy fuel rate, in litres per hour, or `nil` if not available.
  public var fuelRateEconomy: Double?

  /// The instantaneous fuel economy, in litres per hour, or `nil` if not available.
  public var instantaneousFuelEconomy: Double?

  /// Creates an engine trip parameters message.
  ///
  /// The defaults match upstream's `SetN2kEngineTripParameters`.
  public init(
    instance: UInt8,
    tripFuelUsed: Double?,
    fuelRateAverage: Double?,
    fuelRateEconomy: Double? = nil,
    instantaneousFuelEconomy: Double? = nil
  ) {
    self.instance = instance
    self.tripFuelUsed = tripFuelUsed
    self.fuelRateAverage = fuelRateAverage
    self.fuelRateEconomy = fuelRateEconomy
    self.instantaneousFuelEconomy = instantaneousFuelEconomy
  }

  public init(from reader: inout MessageReader) {
    instance = reader.readUInt8()
    tripFuelUsed = reader.readUInt16(resolution: 1)
    fuelRateAverage = reader.readInt16(resolution: 0.1)
    fuelRateEconomy = reader.readInt16(resolution: 0.1)
    instantaneousFuelEconomy = reader.readInt16(resolution: 0.1)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt16(tripFuelUsed, resolution: 1)
    writer.appendInt16(fuelRateAverage, resolution: 0.1)
    writer.appendInt16(fuelRateEconomy, resolution: 0.1)
    writer.appendInt16(instantaneousFuelEconomy, resolution: 0.1)
  }
}
