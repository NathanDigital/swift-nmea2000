// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129026, COG and SOG rapid update: course and speed over ground.
///
/// Ports `SetN2kPGN129026` / `ParseN2kPGN129026`.
public struct COGSOGRapidUpdate: ParameterGroup {
  public static let pgn: UInt32 = 129026
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// Whether the course is true or magnetic.
  public var reference: HeadingReference

  /// The course over ground, in radians, or `nil` if not available.
  public var courseOverGround: Double?

  /// The speed over ground, in meters per second, or `nil` if not available.
  public var speedOverGround: Double?

  /// Creates a COG and SOG rapid update message.
  public init(
    sequenceID: UInt8?,
    reference: HeadingReference,
    courseOverGround: Double?,
    speedOverGround: Double?
  ) {
    self.sequenceID = sequenceID
    self.reference = reference
    self.courseOverGround = courseOverGround
    self.speedOverGround = speedOverGround
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    reference = HeadingReference(rawValue: reader.readUInt8() & 0x03)
    courseOverGround = reader.readUInt16(resolution: 0.0001)
    speedOverGround = reader.readUInt16(resolution: 0.01)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(reference.rawValue & 0x03 | 0xfc)
    writer.appendUInt16(courseOverGround, resolution: 0.0001)
    writer.appendUInt16(speedOverGround, resolution: 0.01)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
