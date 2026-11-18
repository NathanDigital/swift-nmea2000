// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127508, battery status.
///
/// Ports `SetN2kPGN127508` / `ParseN2kPGN127508`.
public struct BatteryStatus: ParameterGroup {
  public static let pgn: UInt32 = 127508
  public static let defaultPriority: UInt8 = 6

  /// The battery instance.
  public var batteryInstance: UInt8

  /// The battery potential, in volts, or `nil` if not available.
  public var voltage: Double?

  /// The battery current, in amperes, positive when charging, or `nil` if not available.
  public var current: Double?

  /// The battery temperature, in kelvins, or `nil` if not available.
  public var temperature: Double?

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// Creates a battery status message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kDCBatStatus`, including its sequence identifier of 1.
  public init(
    batteryInstance: UInt8,
    voltage: Double? = nil,
    current: Double? = nil,
    temperature: Double? = nil,
    sequenceID: UInt8? = 1
  ) {
    self.batteryInstance = batteryInstance
    self.voltage = voltage
    self.current = current
    self.temperature = temperature
    self.sequenceID = sequenceID
  }

  public init(decoding reader: inout MessageReader) {
    batteryInstance = reader.readUInt8()
    voltage = reader.readInt16(resolution: 0.01)
    current = reader.readInt16(resolution: 0.1)
    temperature = reader.readUInt16(resolution: 0.01)
    sequenceID = reader.readOptionalUInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(batteryInstance)
    writer.appendInt16(voltage, resolution: 0.01)
    writer.appendInt16(current, resolution: 0.1)
    writer.appendUInt16(temperature, resolution: 0.01)
    writer.appendUInt8(sequenceID)
  }
}
