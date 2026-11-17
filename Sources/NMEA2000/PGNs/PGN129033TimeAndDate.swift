// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129033, time and date: UTC date and time with the local time offset.
///
/// Ports `SetN2kPGN129033` / `ParseN2kPGN129033`.
public struct TimeAndDate: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129033
  public static let defaultPriority: UInt8 = 3

  /// The date, in days since 1970-01-01, or `nil` if not available.
  public var daysSince1970: UInt16?

  /// The time of day, in seconds since midnight UTC, or `nil` if not available.
  public var secondsSinceMidnight: Double?

  /// The offset of local time from UTC, in minutes, or `nil` if not available.
  public var localOffset: Int16?

  /// Creates a time and date message.
  public init(
    daysSince1970: UInt16?,
    secondsSinceMidnight: Double?,
    localOffset: Int16?
  ) {
    self.daysSince1970 = daysSince1970
    self.secondsSinceMidnight = secondsSinceMidnight
    self.localOffset = localOffset
  }

  public init(from reader: inout MessageReader) {
    daysSince1970 = reader.readOptionalUInt16()
    secondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
    localOffset = reader.readOptionalInt16()
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt16(daysSince1970)
    writer.appendUInt32(secondsSinceMidnight, resolution: 0.0001)
    writer.appendInt16(localOffset)
  }
}
