// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128778, windlass monitoring status: motor time, voltage and current.
///
/// Ports `SetN2kPGN128778` / `ParseN2kPGN128778`.
public struct WindlassMonitoringStatus: ParameterGroup {
  public static let pgn: UInt32 = 128778
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The identifier of the windlass.
  public var windlassID: UInt8

  /// The total motor run time, in seconds, or `nil` if not available.
  public var totalMotorTime: Double?

  /// The controller voltage, in volts, or `nil` if not available.
  public var controllerVoltage: Double?

  /// The motor current, in amperes, or `nil` if not available.
  public var motorCurrent: Double?

  /// The monitoring events. Upstream decodes only the three defined bits.
  public var monitoringEvents: WindlassMonitoringEvents

  /// Creates a windlass monitoring status message.
  ///
  /// The defaults match upstream's `SetN2kPGN128778`.
  public init(
    sequenceID: UInt8?,
    windlassID: UInt8,
    totalMotorTime: Double?,
    controllerVoltage: Double? = nil,
    motorCurrent: Double? = nil,
    monitoringEvents: WindlassMonitoringEvents = []
  ) {
    self.sequenceID = sequenceID
    self.windlassID = windlassID
    self.totalMotorTime = totalMotorTime
    self.controllerVoltage = controllerVoltage
    self.motorCurrent = motorCurrent
    self.monitoringEvents = monitoringEvents
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    windlassID = reader.readUInt8()
    monitoringEvents = WindlassMonitoringEvents(rawValue: reader.readUInt8() & 0x07)
    controllerVoltage = reader.readUInt8(resolution: 0.2)
    motorCurrent = reader.readUInt8(resolution: 1.0)
    totalMotorTime = reader.readUInt16(resolution: 60.0)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(windlassID)
    writer.appendUInt8(monitoringEvents.rawValue)
    writer.appendUInt8(controllerVoltage, resolution: 0.2)
    writer.appendUInt8(motorCurrent, resolution: 1.0)
    writer.appendUInt16(totalMotorTime, resolution: 60.0)
    writer.appendUInt8(0xff)
  }
}
