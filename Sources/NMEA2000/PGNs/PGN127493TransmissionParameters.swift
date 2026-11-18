// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127493, transmission parameters, dynamic.
///
/// Ports `SetN2kPGN127493` / `ParseN2kPGN127493`.
public struct TransmissionParameters: ParameterGroup {
  public static let pgn: UInt32 = 127493
  public static let defaultPriority: UInt8 = 2

  /// The engine instance.
  public var instance: UInt8

  /// The gear the transmission is in.
  public var gear: TransmissionGear

  /// The transmission oil pressure, in pascals, or `nil` if not available.
  public var oilPressure: Double?

  /// The transmission oil temperature, in kelvins, or `nil` if not available.
  public var oilTemperature: Double?

  /// The transmission warning flags.
  public var discreteStatus: TransmissionDiscreteStatus

  /// Creates a transmission parameters message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kTransmissionParameters`.
  public init(
    instance: UInt8,
    gear: TransmissionGear,
    oilPressure: Double? = nil,
    oilTemperature: Double? = nil,
    discreteStatus: TransmissionDiscreteStatus = []
  ) {
    self.instance = instance
    self.gear = gear
    self.oilPressure = oilPressure
    self.oilTemperature = oilTemperature
    self.discreteStatus = discreteStatus
  }

  public init(decoding reader: inout MessageReader) {
    instance = reader.readUInt8()
    gear = TransmissionGear(rawValue: reader.readUInt8() & 0x03)
    oilPressure = reader.readUInt16(resolution: 100)
    oilTemperature = reader.readUInt16(resolution: 0.1)
    discreteStatus = TransmissionDiscreteStatus(rawValue: reader.readUInt8())
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt8(gear.rawValue & 0x03 | 0xfc)
    writer.appendUInt16(oilPressure, resolution: 100)
    writer.appendUInt16(oilTemperature, resolution: 0.1)
    writer.appendUInt8(discreteStatus.rawValue)
    writer.appendUInt8(0xff)
  }
}
