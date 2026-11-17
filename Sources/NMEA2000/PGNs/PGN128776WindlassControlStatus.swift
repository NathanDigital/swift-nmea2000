// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128776, windlass control status: commands sent to a windlass.
///
/// Ports `SetN2kPGN128776` / `ParseN2kPGN128776`.
public struct WindlassControlStatus: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 128776
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The identifier of the windlass.
  public var windlassID: UInt8

  /// The commanded direction.
  public var directionControl: WindlassDirectionControl

  /// The commanded speed. For a proportional speed motor this is a percentage.
  public var speedControl: UInt8

  /// How the motor speed is controlled.
  public var speedControlType: MotorSpeedType

  /// Whether anchor docking is commanded.
  public var anchorDockingControl: BinaryStatus

  /// Whether power is enabled.
  public var powerEnable: BinaryStatus

  /// Whether the mechanical lock is engaged.
  public var mechanicalLock: BinaryStatus

  /// Whether the deck and anchor wash is on.
  public var deckAndAnchorWash: BinaryStatus

  /// Whether the anchor light is on.
  public var anchorLight: BinaryStatus

  /// How long a command stays valid, in seconds, or `nil` if not available.
  public var commandTimeout: Double?

  /// The control events. Upstream decodes only the defined bit.
  public var controlEvents: WindlassControlEvents

  /// Creates a windlass control status message.
  public init(
    sequenceID: UInt8?,
    windlassID: UInt8,
    directionControl: WindlassDirectionControl,
    speedControl: UInt8,
    speedControlType: MotorSpeedType,
    anchorDockingControl: BinaryStatus,
    powerEnable: BinaryStatus,
    mechanicalLock: BinaryStatus,
    deckAndAnchorWash: BinaryStatus,
    anchorLight: BinaryStatus,
    commandTimeout: Double?,
    controlEvents: WindlassControlEvents
  ) {
    self.sequenceID = sequenceID
    self.windlassID = windlassID
    self.directionControl = directionControl
    self.speedControl = speedControl
    self.speedControlType = speedControlType
    self.anchorDockingControl = anchorDockingControl
    self.powerEnable = powerEnable
    self.mechanicalLock = mechanicalLock
    self.deckAndAnchorWash = deckAndAnchorWash
    self.anchorLight = anchorLight
    self.commandTimeout = commandTimeout
    self.controlEvents = controlEvents
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    windlassID = reader.readUInt8()
    let commands = reader.readUInt8()
    directionControl = WindlassDirectionControl(rawValue: commands & 0x03)
    anchorDockingControl = BinaryStatus(rawValue: (commands >> 2) & 0x03)
    speedControlType = MotorSpeedType(rawValue: (commands >> 4) & 0x03)
    speedControl = reader.readUInt8()
    let switches = reader.readUInt8()
    powerEnable = BinaryStatus(rawValue: switches & 0x03)
    mechanicalLock = BinaryStatus(rawValue: (switches >> 2) & 0x03)
    deckAndAnchorWash = BinaryStatus(rawValue: (switches >> 4) & 0x03)
    anchorLight = BinaryStatus(rawValue: (switches >> 6) & 0x03)
    commandTimeout = reader.readUInt8(resolution: 0.005)
    controlEvents = WindlassControlEvents(rawValue: reader.readUInt8() & 0x01)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(windlassID)
    writer.appendUInt8(
      0x03 << 6 | (speedControlType.rawValue & 0x03) << 4 | (anchorDockingControl.rawValue & 0x03)
        << 2
        | directionControl.rawValue & 0x03)
    writer.appendUInt8(speedControl)
    writer.appendUInt8(
      (anchorLight.rawValue & 0x03) << 6 | (deckAndAnchorWash.rawValue & 0x03) << 4
        | (mechanicalLock.rawValue & 0x03) << 2 | powerEnable.rawValue & 0x03)
    writer.appendUInt8(commandTimeout, resolution: 0.005)
    writer.appendUInt8(controlEvents.rawValue)
  }
}
