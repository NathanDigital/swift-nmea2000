// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127237, heading/track control: autopilot commands and limits.
///
/// Ports `SetN2kPGN127237` / `ParseN2kPGN127237`.
public struct HeadingTrackControl: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127237
  public static let defaultPriority: UInt8 = 2

  /// Whether the rudder limit is exceeded.
  public var rudderLimitExceeded: OnOffStatus

  /// Whether the off-heading limit is exceeded.
  public var offHeadingLimitExceeded: OnOffStatus

  /// Whether the off-track limit is exceeded.
  public var offTrackLimitExceeded: OnOffStatus

  /// Whether the autopilot is overridden.
  public var override: OnOffStatus

  /// The steering mode.
  public var steeringMode: SteeringMode

  /// How turns are limited.
  public var turnMode: TurnMode

  /// Whether headings and tracks are true or magnetic.
  public var headingReference: HeadingReference

  /// The commanded rudder direction.
  public var commandedRudderDirection: RudderDirectionOrder

  /// The commanded rudder angle, in radians, or `nil` if not available.
  public var commandedRudderAngle: Double?

  /// The heading or course to steer, in radians, or `nil` if not available.
  public var headingToSteer: Double?

  /// The track, in radians, or `nil` if not available.
  public var track: Double?

  /// The rudder limit, in radians, or `nil` if not available.
  public var rudderLimit: Double?

  /// The off-heading limit, in radians, or `nil` if not available.
  public var offHeadingLimit: Double?

  /// The commanded radius of turn, in meters, or `nil` if not available.
  public var radiusOfTurnOrder: Double?

  /// The commanded rate of turn, in radians per second, or `nil` if not available.
  public var rateOfTurnOrder: Double?

  /// The off-track limit, in meters, or `nil` if not available.
  public var offTrackLimit: Double?

  /// The vessel heading, in radians, or `nil` if not available.
  public var vesselHeading: Double?

  /// Creates a heading/track control message.
  public init(
    rudderLimitExceeded: OnOffStatus,
    offHeadingLimitExceeded: OnOffStatus,
    offTrackLimitExceeded: OnOffStatus,
    override: OnOffStatus,
    steeringMode: SteeringMode,
    turnMode: TurnMode,
    headingReference: HeadingReference,
    commandedRudderDirection: RudderDirectionOrder,
    commandedRudderAngle: Double?,
    headingToSteer: Double?,
    track: Double?,
    rudderLimit: Double?,
    offHeadingLimit: Double?,
    radiusOfTurnOrder: Double?,
    rateOfTurnOrder: Double?,
    offTrackLimit: Double?,
    vesselHeading: Double?
  ) {
    self.rudderLimitExceeded = rudderLimitExceeded
    self.offHeadingLimitExceeded = offHeadingLimitExceeded
    self.offTrackLimitExceeded = offTrackLimitExceeded
    self.override = override
    self.steeringMode = steeringMode
    self.turnMode = turnMode
    self.headingReference = headingReference
    self.commandedRudderDirection = commandedRudderDirection
    self.commandedRudderAngle = commandedRudderAngle
    self.headingToSteer = headingToSteer
    self.track = track
    self.rudderLimit = rudderLimit
    self.offHeadingLimit = offHeadingLimit
    self.radiusOfTurnOrder = radiusOfTurnOrder
    self.rateOfTurnOrder = rateOfTurnOrder
    self.offTrackLimit = offTrackLimit
    self.vesselHeading = vesselHeading
  }

  public init(from reader: inout MessageReader) {
    let limits = reader.readUInt8()
    rudderLimitExceeded = OnOffStatus(rawValue: limits & 0x03)
    offHeadingLimitExceeded = OnOffStatus(rawValue: (limits >> 2) & 0x03)
    offTrackLimitExceeded = OnOffStatus(rawValue: (limits >> 4) & 0x03)
    override = OnOffStatus(rawValue: (limits >> 6) & 0x03)
    let modes = reader.readUInt8()
    steeringMode = SteeringMode(rawValue: modes & 0x07)
    turnMode = TurnMode(rawValue: (modes >> 3) & 0x07)
    headingReference = HeadingReference(rawValue: (modes >> 6) & 0x03)
    commandedRudderDirection = RudderDirectionOrder(rawValue: (reader.readUInt8() >> 5) & 0x07)
    commandedRudderAngle = reader.readInt16(resolution: 0.0001)
    headingToSteer = reader.readUInt16(resolution: 0.0001)
    track = reader.readUInt16(resolution: 0.0001)
    rudderLimit = reader.readUInt16(resolution: 0.0001)
    offHeadingLimit = reader.readUInt16(resolution: 0.0001)
    radiusOfTurnOrder = reader.readInt16(resolution: 1)
    rateOfTurnOrder = reader.readInt16(resolution: 3.125e-5)
    offTrackLimit = reader.readInt16(resolution: 1)
    vesselHeading = reader.readUInt16(resolution: 0.0001)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(
      rudderLimitExceeded.rawValue & 0x03 | (offHeadingLimitExceeded.rawValue & 0x03) << 2
        | (offTrackLimitExceeded.rawValue & 0x03) << 4 | (override.rawValue & 0x03) << 6)
    writer.appendUInt8(
      steeringMode.rawValue & 0x07 | (turnMode.rawValue & 0x07) << 3
        | (headingReference.rawValue & 0x03) << 6)
    writer.appendUInt8(0x1f | (commandedRudderDirection.rawValue & 0x07) << 5)
    writer.appendInt16(commandedRudderAngle, resolution: 0.0001)
    writer.appendUInt16(headingToSteer, resolution: 0.0001)
    writer.appendUInt16(track, resolution: 0.0001)
    writer.appendUInt16(rudderLimit, resolution: 0.0001)
    writer.appendUInt16(offHeadingLimit, resolution: 0.0001)
    writer.appendInt16(radiusOfTurnOrder, resolution: 1)
    writer.appendInt16(rateOfTurnOrder, resolution: 3.125e-5)
    writer.appendInt16(offTrackLimit, resolution: 1)
    writer.appendUInt16(vesselHeading, resolution: 0.0001)
  }
}
