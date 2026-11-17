// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127750, converter status: charger or inverter state.
///
/// Ports `SetN2kPGN127750` / `ParseN2kPGN127750`. ``DCVoltageState/low`` and
/// ``TemperatureState/high`` are sent as 2, not upstream's 3; see `docs/types.md`.
public struct ConverterStatus: ParameterGroup {
  public static let pgn: UInt32 = 127750
  public static let defaultPriority: UInt8 = 6

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The connection number of the converter.
  public var connectionNumber: UInt8

  /// The operating state.
  public var operatingState: ConverterOperatingState

  /// The temperature level.
  public var temperatureState: TemperatureState

  /// The load level.
  public var overloadState: OverloadState

  /// The DC voltage level.
  public var lowDCVoltageState: DCVoltageState

  /// The DC ripple level.
  public var rippleState: RippleState

  /// Creates a converter status message.
  public init(
    sequenceID: UInt8?,
    connectionNumber: UInt8,
    operatingState: ConverterOperatingState,
    temperatureState: TemperatureState,
    overloadState: OverloadState,
    lowDCVoltageState: DCVoltageState,
    rippleState: RippleState
  ) {
    self.sequenceID = sequenceID
    self.connectionNumber = connectionNumber
    self.operatingState = operatingState
    self.temperatureState = temperatureState
    self.overloadState = overloadState
    self.lowDCVoltageState = lowDCVoltageState
    self.rippleState = rippleState
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    connectionNumber = reader.readUInt8()
    operatingState = ConverterOperatingState(rawValue: reader.readUInt8())
    let states = reader.readUInt8()
    rippleState = RippleState(rawValue: (states >> 6) & 0x03)
    lowDCVoltageState = DCVoltageState(rawValue: (states >> 4) & 0x03)
    overloadState = OverloadState(rawValue: (states >> 2) & 0x03)
    temperatureState = TemperatureState(rawValue: states & 0x03)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(connectionNumber)
    writer.appendUInt8(operatingState.rawValue)
    writer.appendUInt8(
      (rippleState.rawValue & 0x03) << 6 | (lowDCVoltageState.rawValue & 0x03) << 4
        | (overloadState.rawValue & 0x03) << 2 | temperatureState.rawValue & 0x03)
    writer.appendUInt32(0xffff_ffff)
  }
}
