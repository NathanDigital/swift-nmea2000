// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127489, engine parameters, dynamic.
///
/// Ports `SetN2kPGN127489` / `ParseN2kPGN127489`.
public struct EngineParametersDynamic: ParameterGroup {
  public static let pgn: UInt32 = 127489
  public static let defaultPriority: UInt8 = 2

  /// The engine instance.
  public var instance: UInt8

  /// The oil pressure, in pascals, or `nil` if not available.
  public var oilPressure: Double?

  /// The oil temperature, in kelvins, or `nil` if not available.
  public var oilTemperature: Double?

  /// The coolant temperature, in kelvins, or `nil` if not available.
  public var coolantTemperature: Double?

  /// The alternator potential, in volts, or `nil` if not available.
  public var alternatorVoltage: Double?

  /// The fuel rate, in litres per hour (as upstream uses), or `nil` if not available.
  public var fuelRate: Double?

  /// The total engine run time, in seconds, or `nil` if not available.
  public var engineHours: Double?

  /// The coolant pressure, in pascals, or `nil` if not available.
  public var coolantPressure: Double?

  /// The fuel pressure, in pascals, or `nil` if not available.
  public var fuelPressure: Double?

  /// The engine load, in percent, or `nil` if not available.
  public var load: Int8?

  /// The engine torque, in percent, or `nil` if not available.
  public var torque: Int8?

  /// The first set of engine warning flags.
  public var status1: EngineDiscreteStatus1

  /// The second set of engine warning flags.
  ///
  /// Upstream's decoder keeps only the low eight bits, so it loses the
  /// manufacturer-defined flags its encoder sends. This type decodes all
  /// sixteen.
  public var status2: EngineDiscreteStatus2

  /// Creates a dynamic engine parameters message.
  ///
  /// The defaults match upstream's `SetN2kEngineDynamicParam`.
  public init(
    instance: UInt8,
    oilPressure: Double?,
    oilTemperature: Double?,
    coolantTemperature: Double?,
    alternatorVoltage: Double?,
    fuelRate: Double?,
    engineHours: Double?,
    coolantPressure: Double? = nil,
    fuelPressure: Double? = nil,
    load: Int8? = nil,
    torque: Int8? = nil,
    status1: EngineDiscreteStatus1 = [],
    status2: EngineDiscreteStatus2 = []
  ) {
    self.instance = instance
    self.oilPressure = oilPressure
    self.oilTemperature = oilTemperature
    self.coolantTemperature = coolantTemperature
    self.alternatorVoltage = alternatorVoltage
    self.fuelRate = fuelRate
    self.engineHours = engineHours
    self.coolantPressure = coolantPressure
    self.fuelPressure = fuelPressure
    self.load = load
    self.torque = torque
    self.status1 = status1
    self.status2 = status2
  }

  public init(decoding reader: inout MessageReader) {
    instance = reader.readUInt8()
    oilPressure = reader.readUInt16(resolution: 100)
    oilTemperature = reader.readUInt16(resolution: 0.1)
    coolantTemperature = reader.readUInt16(resolution: 0.01)
    alternatorVoltage = reader.readInt16(resolution: 0.01)
    fuelRate = reader.readInt16(resolution: 0.1)
    engineHours = reader.readUInt32(resolution: 1)
    coolantPressure = reader.readUInt16(resolution: 100)
    fuelPressure = reader.readUInt16(resolution: 1000)
    _ = reader.readUInt8()  // Reserved.
    status1 = EngineDiscreteStatus1(rawValue: reader.readUInt16())
    // Deliberate divergence: upstream assigns through tN2kDD223::operator=,
    // which keeps only the low byte.
    status2 = EngineDiscreteStatus2(rawValue: reader.readUInt16())
    load = reader.readOptionalInt8()
    torque = reader.readOptionalInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt16(oilPressure, resolution: 100)
    writer.appendUInt16(oilTemperature, resolution: 0.1)
    writer.appendUInt16(coolantTemperature, resolution: 0.01)
    writer.appendInt16(alternatorVoltage, resolution: 0.01)
    writer.appendInt16(fuelRate, resolution: 0.1)
    writer.appendUInt32(engineHours, resolution: 1)
    writer.appendUInt16(coolantPressure, resolution: 100)
    writer.appendUInt16(fuelPressure, resolution: 1000)
    writer.appendUInt8(0xff)
    writer.appendUInt16(status1.rawValue)
    writer.appendUInt16(status2.rawValue)
    writer.appendInt8(load)
    writer.appendInt8(torque)
  }
}
