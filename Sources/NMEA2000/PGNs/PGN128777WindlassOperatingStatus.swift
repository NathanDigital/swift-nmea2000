// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128777, windlass operating status: motion, rode and docking state.
///
/// Ports `SetN2kPGN128777` / `ParseN2kPGN128777`.
public struct WindlassOperatingStatus: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 128777
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The identifier of the windlass.
  public var windlassID: UInt8

  /// The length of rode deployed, in meters, or `nil` if not available.
  public var rodeCounter: Double?

  /// The speed of the rode, in meters per second, or `nil` if not available.
  public var lineSpeed: Double?

  /// The motion of the windlass.
  public var motionState: WindlassMotionState

  /// The kind of rode detected.
  public var rodeType: RodeType

  /// Whether the anchor is docked.
  public var anchorDockingState: AnchorDockingState

  /// The operating events. Only the low six bits fit on the wire, and upstream decodes only the
  /// five defined bits.
  public var operatingEvents: WindlassOperatingEvents

  /// Creates a windlass operating status message.
  public init(
    sequenceID: UInt8?,
    windlassID: UInt8,
    rodeCounter: Double?,
    lineSpeed: Double?,
    motionState: WindlassMotionState,
    rodeType: RodeType,
    anchorDockingState: AnchorDockingState,
    operatingEvents: WindlassOperatingEvents
  ) {
    self.sequenceID = sequenceID
    self.windlassID = windlassID
    self.rodeCounter = rodeCounter
    self.lineSpeed = lineSpeed
    self.motionState = motionState
    self.rodeType = rodeType
    self.anchorDockingState = anchorDockingState
    self.operatingEvents = operatingEvents
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    windlassID = reader.readUInt8()
    let states = reader.readUInt8()
    motionState = WindlassMotionState(rawValue: states & 0x03)
    rodeType = RodeType(rawValue: (states >> 2) & 0x03)
    rodeCounter = reader.readUInt16(resolution: 0.1)
    lineSpeed = reader.readUInt16(resolution: 0.01)
    let docking = reader.readUInt8()
    anchorDockingState = AnchorDockingState(rawValue: docking & 0x03)
    operatingEvents = WindlassOperatingEvents(rawValue: (docking >> 2) & 0x1f)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(windlassID)
    writer.appendUInt8(0xf0 | (rodeType.rawValue & 0x03) << 2 | motionState.rawValue & 0x03)
    writer.appendUInt16(rodeCounter, resolution: 0.1)
    writer.appendUInt16(lineSpeed, resolution: 0.01)
    writer.appendUInt8(operatingEvents.rawValue << 2 | anchorDockingState.rawValue & 0x03)
  }
}
