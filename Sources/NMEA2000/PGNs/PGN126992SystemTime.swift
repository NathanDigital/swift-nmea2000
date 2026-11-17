// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126992, system time: the date and time from a time source.
///
/// Ports `SetN2kPGN126992` / `ParseN2kPGN126992`.
public struct SystemTime: ParameterGroup {
  public static let pgn: UInt32 = 126992
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The date, in days since 1970-01-01, or `nil` if not available.
  public var daysSince1970: UInt16?

  /// The time of day, in seconds since midnight UTC, or `nil` if not available.
  public var secondsSinceMidnight: Double?

  /// The source of the time.
  public var source: TimeSource

  /// Creates a system time message.
  ///
  /// The default matches upstream's `SetN2kPGN126992`.
  public init(
    sequenceID: UInt8?,
    daysSince1970: UInt16?,
    secondsSinceMidnight: Double?,
    source: TimeSource = .gps
  ) {
    self.sequenceID = sequenceID
    self.daysSince1970 = daysSince1970
    self.secondsSinceMidnight = secondsSinceMidnight
    self.source = source
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    source = TimeSource(rawValue: reader.readUInt8() & 0x0f)
    daysSince1970 = reader.readOptionalUInt16()
    secondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(source.rawValue & 0x0f | 0xf0)
    writer.appendUInt16(daysSince1970)
    writer.appendUInt32(secondsSinceMidnight, resolution: 0.0001)
  }
}
