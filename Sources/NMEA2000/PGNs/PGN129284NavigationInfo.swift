// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129284, navigation data: progress toward the destination waypoint.
///
/// Ports `SetN2kPGN129284` / `ParseN2kPGN129284`.
public struct NavigationInfo: ParameterGroup {
  public static let pgn: UInt32 = 129284
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The distance to the destination waypoint, in metres, or `nil` if not available.
  public var distanceToWaypoint: Double?

  /// Whether the bearings are true or magnetic.
  ///
  /// The field is two bits wide. Upstream decodes only bit 0, so it reads
  /// ``HeadingReference/error`` and ``HeadingReference/unavailable`` as
  /// ``HeadingReference/magnetic``. This type decodes both bits.
  public var bearingReference: HeadingReference

  /// A Boolean value that indicates whether the perpendicular through the destination waypoint has
  /// been crossed, or `nil` if not available.
  ///
  /// The field is two bits wide. Upstream decodes only bit 0, so it reads
  /// error and not available as `true`; this type decodes both as `nil`,
  /// and sends `nil` as not available, which upstream's `bool` can't.
  public var isPerpendicularCrossed: Bool?

  /// A Boolean value that indicates whether the arrival circle has been entered, or `nil` if not
  /// available.
  ///
  /// Two bits wide, like ``isPerpendicularCrossed``.
  public var isArrivalCircleEntered: Bool?

  /// How distances and bearings are calculated.
  ///
  /// The field is two bits wide. Upstream decodes only bit 0 and sends
  /// anything but ``DistanceCalculationType/rhumbLine`` as
  /// ``DistanceCalculationType/greatCircle``; this type decodes both bits
  /// and sends other values unchanged, so they round-trip.
  public var calculationType: DistanceCalculationType

  /// The estimated date of arrival, in days since 1970-01-01, or `nil` if not available.
  public var etaDaysSince1970: UInt16?

  /// The estimated time of arrival, in seconds since midnight UTC, or `nil` if not available.
  public var etaSecondsSinceMidnight: Double?

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

  /// The speed toward the destination waypoint, in metres per second, or `nil` if not available.
  public var waypointClosingVelocity: Double?

  /// Creates a navigation data message.
  public init(
    bearingReference: HeadingReference,
    calculationType: DistanceCalculationType,
    sequenceID: UInt8? = nil,
    distanceToWaypoint: Double? = nil,
    isPerpendicularCrossed: Bool? = nil,
    isArrivalCircleEntered: Bool? = nil,
    etaDaysSince1970: UInt16? = nil,
    etaSecondsSinceMidnight: Double? = nil,
    bearingOriginToDestination: Double? = nil,
    bearingPositionToDestination: Double? = nil,
    originWaypointNumber: UInt32? = nil,
    destinationWaypointNumber: UInt32? = nil,
    destinationLatitude: Double? = nil,
    destinationLongitude: Double? = nil,
    waypointClosingVelocity: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.distanceToWaypoint = distanceToWaypoint
    self.bearingReference = bearingReference
    self.isPerpendicularCrossed = isPerpendicularCrossed
    self.isArrivalCircleEntered = isArrivalCircleEntered
    self.calculationType = calculationType
    self.etaDaysSince1970 = etaDaysSince1970
    self.etaSecondsSinceMidnight = etaSecondsSinceMidnight
    self.bearingOriginToDestination = bearingOriginToDestination
    self.bearingPositionToDestination = bearingPositionToDestination
    self.originWaypointNumber = originWaypointNumber
    self.destinationWaypointNumber = destinationWaypointNumber
    self.destinationLatitude = destinationLatitude
    self.destinationLongitude = destinationLongitude
    self.waypointClosingVelocity = waypointClosingVelocity
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    distanceToWaypoint = reader.readUInt32(resolution: 0.01)
    let flags = reader.readUInt8()
    bearingReference = HeadingReference(rawValue: flags & 0x03)
    isPerpendicularCrossed = Bool(twoBitFlag: flags >> 2)
    isArrivalCircleEntered = Bool(twoBitFlag: flags >> 4)
    calculationType = DistanceCalculationType(rawValue: flags >> 6 & 0x03)
    etaSecondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
    etaDaysSince1970 = reader.readOptionalUInt16()
    bearingOriginToDestination = reader.readUInt16(resolution: 0.0001)
    bearingPositionToDestination = reader.readUInt16(resolution: 0.0001)
    originWaypointNumber = reader.readOptionalUInt32()
    destinationWaypointNumber = reader.readOptionalUInt32()
    destinationLatitude = reader.readInt32(resolution: 1e-07)
    destinationLongitude = reader.readInt32(resolution: 1e-07)
    waypointClosingVelocity = reader.readInt16(resolution: 0.01)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt32(distanceToWaypoint, resolution: 0.01)
    writer.appendUInt8(
      bearingReference.rawValue | isPerpendicularCrossed.twoBitFlag << 2
        | isArrivalCircleEntered.twoBitFlag << 4 | (calculationType.rawValue & 0x03) << 6)
    writer.appendUInt32(etaSecondsSinceMidnight, resolution: 0.0001)
    writer.appendUInt16(etaDaysSince1970)
    writer.appendUInt16(bearingOriginToDestination, resolution: 0.0001)
    writer.appendUInt16(bearingPositionToDestination, resolution: 0.0001)
    writer.appendUInt32(originWaypointNumber)
    writer.appendUInt32(destinationWaypointNumber)
    writer.appendInt32(destinationLatitude, resolution: 1e-07)
    writer.appendInt32(destinationLongitude, resolution: 1e-07)
    writer.appendInt16(waypointClosingVelocity, resolution: 0.01)
  }
}
