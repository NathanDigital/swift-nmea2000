// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130316, temperature, extended range.
///
/// Ports `SetN2kPGN130316` / `ParseN2kPGN130316`.
public struct TemperatureExtendedRange: ParameterGroup {
  public static let pgn: UInt32 = 130316
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

  /// Creates an extended range temperature message.
  ///
  /// The default matches upstream's `SetN2kPGN130316`.
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

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    source = TemperatureSource(rawValue: reader.readUInt8())
    actualTemperature = reader.readUInt24(resolution: 0.001)
    setTemperature = reader.readUInt16(resolution: 0.1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(source.rawValue)
    writer.appendUInt24(actualTemperature, resolution: 0.001)
    writer.appendUInt16(setTemperature, resolution: 0.1)
  }
}
