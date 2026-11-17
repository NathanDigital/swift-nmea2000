// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130312, temperature: an actual and set temperature.
///
/// Ports `SetN2kPGN130312` / `ParseN2kPGN130312`.
public struct Temperature: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 130312
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The temperature instance.
  public var instance: UInt8

  /// What the temperature represents.
  public var source: TemperatureSource

  /// The measured temperature, in kelvins, or `nil` if not available.
  public var actualTemperature: Double?

  /// The target temperature, in kelvins, or `nil` if not available.
  public var setTemperature: Double?

  /// Creates a temperature message.
  ///
  /// The default matches upstream's `SetN2kPGN130312`.
  public init(
    sequenceID: UInt8?,
    instance: UInt8,
    source: TemperatureSource,
    actualTemperature: Double?,
    setTemperature: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.source = source
    self.actualTemperature = actualTemperature
    self.setTemperature = setTemperature
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    source = TemperatureSource(rawValue: reader.readUInt8())
    actualTemperature = reader.readUInt16(resolution: 0.01)
    setTemperature = reader.readUInt16(resolution: 0.01)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(source.rawValue)
    writer.appendUInt16(actualTemperature, resolution: 0.01)
    writer.appendUInt16(setTemperature, resolution: 0.01)
    writer.appendUInt8(0xff)
  }
}
