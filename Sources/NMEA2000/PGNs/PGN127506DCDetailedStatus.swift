// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127506, DC detailed status.
///
/// Ports `SetN2kPGN127506` / `ParseN2kPGN127506`.
public struct DCDetailedStatus: ParameterGroup {
  public static let pgn: UInt32 = 127506
  public static let defaultPriority: UInt8 = 6

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The DC source instance.
  public var dcInstance: UInt8

  /// The kind of DC source.
  public var dcType: DCSourceType

  /// The state of charge, in percent, or `nil` if not available.
  public var stateOfCharge: UInt8?

  /// The state of health, in percent, or `nil` if not available.
  public var stateOfHealth: UInt8?

  /// The estimated time remaining, in seconds, or `nil` if not available.
  public var timeRemaining: Double?

  /// The output voltage ripple, in volts, or `nil` if not available.
  public var rippleVoltage: Double?

  /// The battery capacity, in coulombs, or `nil` if not available.
  public var capacity: Double?

  /// Creates a DC detailed status message.
  ///
  /// The defaults match upstream's `SetN2kDCStatus`.
  public init(
    sequenceID: UInt8?,
    dcInstance: UInt8,
    dcType: DCSourceType,
    stateOfCharge: UInt8?,
    stateOfHealth: UInt8?,
    timeRemaining: Double?,
    rippleVoltage: Double? = nil,
    capacity: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.dcInstance = dcInstance
    self.dcType = dcType
    self.stateOfCharge = stateOfCharge
    self.stateOfHealth = stateOfHealth
    self.timeRemaining = timeRemaining
    self.rippleVoltage = rippleVoltage
    self.capacity = capacity
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    dcInstance = reader.readUInt8()
    dcType = DCSourceType(rawValue: reader.readUInt8())
    stateOfCharge = reader.readOptionalUInt8()
    stateOfHealth = reader.readOptionalUInt8()
    timeRemaining = reader.readUInt16(resolution: 60)
    rippleVoltage = reader.readUInt16(resolution: 0.001)
    capacity = reader.readUInt16(resolution: 3600)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(dcInstance)
    writer.appendUInt8(dcType.rawValue)
    writer.appendUInt8(stateOfCharge)
    writer.appendUInt8(stateOfHealth)
    writer.appendUInt16(timeRemaining, resolution: 60)
    writer.appendUInt16(rippleVoltage, resolution: 0.001)
    writer.appendUInt16(capacity, resolution: 3600)
  }
}
