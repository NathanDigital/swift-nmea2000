// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127257, attitude: yaw, pitch and roll.
///
/// Ports `SetN2kPGN127257` / `ParseN2kPGN127257`.
public struct Attitude: ParameterGroup {
  public static let pgn: UInt32 = 127257
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The yaw, in radians, or `nil` if not available.
  public var yaw: Double?

  /// The pitch, in radians, positive when the bow rises, or `nil` if not available.
  public var pitch: Double?

  /// The roll, in radians, positive when tilted to starboard, or `nil` if not available.
  public var roll: Double?

  /// Creates an attitude message.
  public init(
    sequenceID: UInt8? = nil,
    yaw: Double? = nil,
    pitch: Double? = nil,
    roll: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.yaw = yaw
    self.pitch = pitch
    self.roll = roll
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    yaw = reader.readInt16(resolution: 0.0001)
    pitch = reader.readInt16(resolution: 0.0001)
    roll = reader.readInt16(resolution: 0.0001)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendInt16(yaw, resolution: 0.0001)
    writer.appendInt16(pitch, resolution: 0.0001)
    writer.appendInt16(roll, resolution: 0.0001)
    writer.appendUInt8(0xff)
  }
}
