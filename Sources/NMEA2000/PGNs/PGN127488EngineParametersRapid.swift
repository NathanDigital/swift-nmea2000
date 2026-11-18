// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127488, engine parameters, rapid update.
///
/// Ports `SetN2kPGN127488` / `ParseN2kPGN127488`.
public struct EngineParametersRapid: ParameterGroup {
  public static let pgn: UInt32 = 127488
  public static let defaultPriority: UInt8 = 2

  /// The engine instance.
  public var instance: UInt8

  /// The engine speed, in revolutions per minute (as upstream uses), or `nil` if not available.
  public var speed: Double?

  /// The turbocharger boost pressure, in pascals, or `nil` if not available.
  public var boostPressure: Double?

  /// The engine tilt or trim, in percent, or `nil` if not available.
  public var tiltTrim: Int8?

  /// Creates a rapid engine parameters message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kEngineParamRapid`.
  public init(
    instance: UInt8,
    speed: Double? = nil,
    boostPressure: Double? = nil,
    tiltTrim: Int8? = nil
  ) {
    self.instance = instance
    self.speed = speed
    self.boostPressure = boostPressure
    self.tiltTrim = tiltTrim
  }

  public init(decoding reader: inout MessageReader) {
    instance = reader.readUInt8()
    speed = reader.readUInt16(resolution: 0.25)
    boostPressure = reader.readUInt16(resolution: 100)
    tiltTrim = reader.readOptionalInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt16(speed, resolution: 0.25)
    writer.appendUInt16(boostPressure, resolution: 100)
    writer.appendInt8(tiltTrim)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
