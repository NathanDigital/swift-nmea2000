// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130313, humidity: an actual and set humidity.
///
/// Ports `SetN2kPGN130313` / `ParseN2kPGN130313`.
public struct Humidity: ParameterGroup {
  public static let pgn: UInt32 = 130313
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The humidity instance.
  public var instance: UInt8

  /// Where the humidity is measured.
  public var source: HumiditySource

  /// The measured relative humidity, in percent, or `nil` if not available.
  public var actualHumidity: Double?

  /// The target relative humidity, in percent, or `nil` if not available.
  public var setHumidity: Double?

  /// Creates a humidity message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kPGN130313`.
  public init(
    instance: UInt8,
    source: HumiditySource,
    sequenceID: UInt8? = nil,
    actualHumidity: Double? = nil,
    setHumidity: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.source = source
    self.actualHumidity = actualHumidity
    self.setHumidity = setHumidity
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    source = HumiditySource(rawValue: reader.readUInt8())
    actualHumidity = reader.readInt16(resolution: 0.004)
    setHumidity = reader.readInt16(resolution: 0.004)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(source.rawValue)
    writer.appendInt16(actualHumidity, resolution: 0.004)
    writer.appendInt16(setHumidity, resolution: 0.004)
    writer.appendUInt8(0xff)
  }
}
