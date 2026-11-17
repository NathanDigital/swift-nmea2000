// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128275, distance log: total and trip distance through water.
///
/// Ports `SetN2kPGN128275` / `ParseN2kPGN128275`.
public struct DistanceLog: ParameterGroup {
  public static let pgn: UInt32 = 128275
  public static let defaultPriority: UInt8 = 6

  /// The date of the log entry, in days since 1970-01-01, or `nil` if not available.
  public var daysSince1970: UInt16?

  /// The time of the log entry, in seconds since midnight UTC, or `nil` if not available.
  public var secondsSinceMidnight: Double?

  /// The total distance logged, in meters, or `nil` if not available.
  public var log: UInt32?

  /// The distance logged since the last reset, in meters, or `nil` if not available.
  public var tripLog: UInt32?

  /// Creates a distance log message.
  public init(
    daysSince1970: UInt16?,
    secondsSinceMidnight: Double?,
    log: UInt32?,
    tripLog: UInt32?
  ) {
    self.daysSince1970 = daysSince1970
    self.secondsSinceMidnight = secondsSinceMidnight
    self.log = log
    self.tripLog = tripLog
  }

  public init(decoding reader: inout MessageReader) {
    daysSince1970 = reader.readOptionalUInt16()
    secondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
    log = reader.readOptionalUInt32()
    tripLog = reader.readOptionalUInt32()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(daysSince1970)
    writer.appendUInt32(secondsSinceMidnight, resolution: 0.0001)
    writer.appendUInt32(log)
    writer.appendUInt32(tripLog)
  }
}
