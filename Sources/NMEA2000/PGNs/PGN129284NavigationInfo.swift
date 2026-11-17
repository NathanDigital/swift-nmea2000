// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129284, navigation data: progress toward the destination waypoint.
///
/// Ports `SetN2kPGN129284` / `ParseN2kPGN129284`.
public struct NavigationInfo: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129284
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The distance to the destination waypoint, in meters, or `nil` if not available.
  public var distanceToWaypoint: Double?

  /// Whether the bearings are true or magnetic.
  ///
  /// The field is two bits wide. Upstream decodes only bit 0, so it reads
  /// ``HeadingReference/error`` and ``HeadingReference/unavailable`` as
  /// ``HeadingReference/magnetic``. This type decodes both bits.
  public var bearingReference: HeadingReference

  /// A Boolean value that indicates whether the perpendicular through the destination waypoint has
  /// been crossed.
  public var isPerpendicularCrossed: Bool

  /// A Boolean value that indicates whether the arrival circle has been entered.
  public var isArrivalCircleEntered: Bool

  /// How distances and bearings are calculated.
  public var calculationType: DistanceCalculationType

  /// The estimated time of arrival, in seconds since midnight UTC, or `nil` if not available.
  public var etaTime: Double?

  /// The estimated date of arrival, in days since 1970-01-01, or `nil` if not available.
  public var etaDate: UInt16?

  /// The bearing from the origin waypoint to the destination waypoint, in radians, or `nil` if not
  /// available.
  public var bearingOriginToDestination: Double?

  /// The bearing from the current position to the destination waypoint, in radians, or `nil` if not
  /// available.
  public var bearingPositionToDestination: Double?

  /// The number of the origin waypoint, or `nil` if not available.
  public var originWaypointNumber: UInt32?

  /// The number of the destination waypoint, or `nil` if not available.
  public var destinationWaypointNumber: UInt32?

  /// The latitude of the destination waypoint, in degrees, positive north, or `nil` if not
  /// available.
  public var destinationLatitude: Double?

  /// The longitude of the destination waypoint, in degrees, positive east, or `nil` if not
  /// available.
  public var destinationLongitude: Double?

  /// The speed toward the destination waypoint, in meters per second, or `nil` if not available.
  public var waypointClosingVelocity: Double?

  /// Creates a navigation data message.
  public init(
    sequenceID: UInt8?,
    distanceToWaypoint: Double?,
    bearingReference: HeadingReference,
    isPerpendicularCrossed: Bool,
    isArrivalCircleEntered: Bool,
    calculationType: DistanceCalculationType,
    etaTime: Double?,
    etaDate: UInt16?,
    bearingOriginToDestination: Double?,
    bearingPositionToDestination: Double?,
    originWaypointNumber: UInt32?,
    destinationWaypointNumber: UInt32?,
    destinationLatitude: Double?,
    destinationLongitude: Double?,
    waypointClosingVelocity: Double?
  ) {
    self.sequenceID = sequenceID
    self.distanceToWaypoint = distanceToWaypoint
    self.bearingReference = bearingReference
    self.isPerpendicularCrossed = isPerpendicularCrossed
    self.isArrivalCircleEntered = isArrivalCircleEntered
    self.calculationType = calculationType
    self.etaTime = etaTime
    self.etaDate = etaDate
    self.bearingOriginToDestination = bearingOriginToDestination
    self.bearingPositionToDestination = bearingPositionToDestination
    self.originWaypointNumber = originWaypointNumber
    self.destinationWaypointNumber = destinationWaypointNumber
    self.destinationLatitude = destinationLatitude
    self.destinationLongitude = destinationLongitude
    self.waypointClosingVelocity = waypointClosingVelocity
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    distanceToWaypoint = reader.readUInt32(resolution: 0.01)
    let flags = reader.readUInt8()
    bearingReference = HeadingReference(rawValue: flags & 0x03)
    isPerpendicularCrossed = flags & 0x04 != 0
    isArrivalCircleEntered = flags & 0x10 != 0
    calculationType = flags & 0x40 != 0 ? .rhumbLine : .greatCircle
    etaTime = reader.readUInt32(resolution: 0.0001)
    etaDate = reader.readOptionalUInt16()
    bearingOriginToDestination = reader.readUInt16(resolution: 0.0001)
    bearingPositionToDestination = reader.readUInt16(resolution: 0.0001)
    originWaypointNumber = reader.readOptionalUInt32()
    destinationWaypointNumber = reader.readOptionalUInt32()
    destinationLatitude = reader.readInt32(resolution: 1e-07)
    destinationLongitude = reader.readInt32(resolution: 1e-07)
    waypointClosingVelocity = reader.readInt16(resolution: 0.01)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt32(distanceToWaypoint, resolution: 0.01)
    writer.appendUInt8(
      bearingReference.rawValue | (isPerpendicularCrossed ? 0x04 : 0)
        | (isArrivalCircleEntered ? 0x10 : 0) | (calculationType == .rhumbLine ? 0x40 : 0))
    writer.appendUInt32(etaTime, resolution: 0.0001)
    writer.appendUInt16(etaDate)
    writer.appendUInt16(bearingOriginToDestination, resolution: 0.0001)
    writer.appendUInt16(bearingPositionToDestination, resolution: 0.0001)
    writer.appendUInt32(originWaypointNumber)
    writer.appendUInt32(destinationWaypointNumber)
    writer.appendInt32(destinationLatitude, resolution: 1e-07)
    writer.appendInt32(destinationLongitude, resolution: 1e-07)
    writer.appendInt16(waypointClosingVelocity, resolution: 0.01)
  }
}
