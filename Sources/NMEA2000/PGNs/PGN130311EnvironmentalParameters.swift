// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130311, environmental parameters: temperature, humidity and pressure.
///
/// Ports `SetN2kPGN130311` / `ParseN2kPGN130311`. This port decodes the two-bit humidity source
/// code 3 as ``HumiditySource/undefined``; see ``humiditySource``.
public struct EnvironmentalParameters: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 130311
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// What the temperature represents. Only the low six bits are sent.
  public var temperatureSource: TemperatureSource

  /// The temperature, in kelvins, or `nil` if not available.
  public var temperature: Double?

  /// Where the humidity is measured. The field is two bits wide, so ``HumiditySource/undefined``
  /// (255) is sent as 3. Upstream decodes it as 3, which no longer equals its own constant; this
  /// port decodes 3 as ``HumiditySource/undefined``.
  public var humiditySource: HumiditySource

  /// The relative humidity, in percent, or `nil` if not available.
  public var humidity: Double?

  /// The atmospheric pressure, in pascals, or `nil` if not available.
  public var atmosphericPressure: Double?

  /// Creates an environmental parameters message.
  ///
  /// The defaults match upstream's `SetN2kPGN130311`.
  public init(
    sequenceID: UInt8?,
    temperatureSource: TemperatureSource,
    temperature: Double?,
    humiditySource: HumiditySource = .undefined,
    humidity: Double? = nil,
    atmosphericPressure: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.temperatureSource = temperatureSource
    self.temperature = temperature
    self.humiditySource = humiditySource
    self.humidity = humidity
    self.atmosphericPressure = atmosphericPressure
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    let sources = reader.readUInt8()
    temperatureSource = TemperatureSource(rawValue: sources & 0x3f)
    // Deliberate divergence: upstream leaves 3 as a raw value.
    let humidityCode = (sources >> 6) & 0x03
    humiditySource = humidityCode == 0x03 ? .undefined : HumiditySource(rawValue: humidityCode)
    temperature = reader.readUInt16(resolution: 0.01)
    humidity = reader.readInt16(resolution: 0.004)
    atmosphericPressure = reader.readUInt16(resolution: 100)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8((humiditySource.rawValue & 0x03) << 6 | temperatureSource.rawValue & 0x3f)
    writer.appendUInt16(temperature, resolution: 0.01)
    writer.appendInt16(humidity, resolution: 0.004)
    writer.appendUInt16(atmosphericPressure, resolution: 100)
  }
}
