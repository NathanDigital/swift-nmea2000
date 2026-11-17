// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127252, heave: vertical displacement of the vessel.
///
/// Ports `SetN2kPGN127252` / `ParseN2kPGN127252`.
public struct Heave: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127252
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The vertical displacement perpendicular to the earth’s surface, in meters, or `nil` if not
  /// available.
  public var heave: Double?

  /// The delay added by calculations, in seconds, or `nil` if not available.
  public var delay: Double?

  /// The source of the delay value.
  public var delaySource: DelaySource

  /// Creates a heave message.
  public init(
    sequenceID: UInt8?,
    heave: Double?,
    delay: Double?,
    delaySource: DelaySource
  ) {
    self.sequenceID = sequenceID
    self.heave = heave
    self.delay = delay
    self.delaySource = delaySource
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    heave = reader.readInt16(resolution: 0.01)
    delay = reader.readUInt16(resolution: 0.01)
    delaySource = DelaySource(rawValue: reader.readUInt8() & 0x0f)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendInt16(heave, resolution: 0.01)
    writer.appendUInt16(delay, resolution: 0.01)
    writer.appendUInt8(0xf0 | delaySource.rawValue & 0x0f)
    writer.appendUInt16(0xffff)
  }
}
