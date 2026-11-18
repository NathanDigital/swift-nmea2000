// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127497, trip parameters, engine.
///
/// Ports `SetN2kPGN127497` / `ParseN2kPGN127497`.
public struct EngineTripParameters: ParameterGroup {
  public static let pgn: UInt32 = 127497
  public static let defaultPriority: UInt8 = 2

  /// The engine instance.
  public var instance: UInt8

  /// The fuel used this trip, in litres as upstream uses them, or `nil` if not available.
  public var tripFuelUsedLitres: Double?

  /// The average fuel rate, in litres per hour, or `nil` if not available.
  public var averageFuelRateLitresPerHour: Double?

  /// The economy fuel rate, in litres per hour, or `nil` if not available.
  public var economyFuelRateLitresPerHour: Double?

  /// The instantaneous fuel economy, in litres per hour, or `nil` if not available.
  public var instantaneousFuelEconomyLitresPerHour: Double?

  /// Creates an engine trip parameters message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kEngineTripParameters`.
  public init(
    instance: UInt8,
    tripFuelUsedLitres: Double? = nil,
    averageFuelRateLitresPerHour: Double? = nil,
    economyFuelRateLitresPerHour: Double? = nil,
    instantaneousFuelEconomyLitresPerHour: Double? = nil
  ) {
    self.instance = instance
    self.tripFuelUsedLitres = tripFuelUsedLitres
    self.averageFuelRateLitresPerHour = averageFuelRateLitresPerHour
    self.economyFuelRateLitresPerHour = economyFuelRateLitresPerHour
    self.instantaneousFuelEconomyLitresPerHour = instantaneousFuelEconomyLitresPerHour
  }

  public init(decoding reader: inout MessageReader) {
    instance = reader.readUInt8()
    tripFuelUsedLitres = reader.readUInt16(resolution: 1)
    averageFuelRateLitresPerHour = reader.readInt16(resolution: 0.1)
    economyFuelRateLitresPerHour = reader.readInt16(resolution: 0.1)
    instantaneousFuelEconomyLitresPerHour = reader.readInt16(resolution: 0.1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt16(tripFuelUsedLitres, resolution: 1)
    writer.appendInt16(averageFuelRateLitresPerHour, resolution: 0.1)
    writer.appendInt16(economyFuelRateLitresPerHour, resolution: 0.1)
    writer.appendInt16(instantaneousFuelEconomyLitresPerHour, resolution: 0.1)
  }
}
