// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130577, direction data: course, heading, set and drift.
///
/// Ports `SetN2kPGN130577` / `ParseN2kPGN130577`.
public struct DirectionData: ParameterGroup {
  public static let pgn: UInt32 = 130577
  public static let defaultPriority: UInt8 = 3

  /// The mode the data was produced in.
  public var dataMode: DataMode

  /// Whether the course over ground is true or magnetic.
  public var courseReference: HeadingReference

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The course over ground, in radians, or `nil` if not available.
  public var courseOverGround: Double?

  /// The speed over ground, in metres per second, or `nil` if not available.
  public var speedOverGround: Double?

  /// The heading, in radians, or `nil` if not available.
  public var heading: Double?

  /// The speed through water, in metres per second, or `nil` if not available.
  public var speedThroughWater: Double?

  /// The direction of the current, in radians, or `nil` if not available.
  public var set: Double?

  /// The speed of the current, in metres per second, or `nil` if not available.
  public var drift: Double?

  /// Creates a direction data message.
  public init(
    dataMode: DataMode,
    courseReference: HeadingReference,
    sequenceID: UInt8? = nil,
    courseOverGround: Double? = nil,
    speedOverGround: Double? = nil,
    heading: Double? = nil,
    speedThroughWater: Double? = nil,
    set: Double? = nil,
    drift: Double? = nil
  ) {
    self.dataMode = dataMode
    self.courseReference = courseReference
    self.sequenceID = sequenceID
    self.courseOverGround = courseOverGround
    self.speedOverGround = speedOverGround
    self.heading = heading
    self.speedThroughWater = speedThroughWater
    self.set = set
    self.drift = drift
  }

  public init(decoding reader: inout MessageReader) {
    let modes = reader.readUInt8()
    dataMode = DataMode(rawValue: modes & 0x0f)
    courseReference = HeadingReference(rawValue: (modes >> 4) & 0x03)
    sequenceID = reader.readOptionalUInt8()
    courseOverGround = reader.readUInt16(resolution: 0.0001)
    speedOverGround = reader.readUInt16(resolution: 0.01)
    heading = reader.readUInt16(resolution: 0.0001)
    speedThroughWater = reader.readUInt16(resolution: 0.01)
    set = reader.readUInt16(resolution: 0.0001)
    drift = reader.readUInt16(resolution: 0.01)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(dataMode.rawValue & 0x0f | (courseReference.rawValue & 0x03) << 4 | 0xc0)
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(courseOverGround, resolution: 0.0001)
    writer.appendUInt16(speedOverGround, resolution: 0.01)
    writer.appendUInt16(heading, resolution: 0.0001)
    writer.appendUInt16(speedThroughWater, resolution: 0.01)
    writer.appendUInt16(set, resolution: 0.0001)
    writer.appendUInt16(drift, resolution: 0.01)
  }
}
