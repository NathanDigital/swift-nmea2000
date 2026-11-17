// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126993, heartbeat: tells other devices this one is still on the bus,
/// and how often it says so.
///
/// ``Node`` sends it every minute.
///
/// Ports `SetN2kPGN126993` / `SetHeartbeat`, with one deliberate fix: upstream
/// accepts intervals up to 655.32 s but sends one over 65.535 s cut to its
/// low 16 bits (70 s goes out as 4.464 s). This port sends `0xfffe`, upstream's
/// own value for an interval too long, instead.
public struct Heartbeat: ParameterGroup {
  public static let pgn: UInt32 = 126993
  public static let defaultPriority: UInt8 = 7

  /// The time between heartbeats, in seconds, or `nil` if not available.
  public var interval: Double?

  /// A counter that goes up by one with each heartbeat and wraps after 252,
  /// or `nil` if not available. Upstream sends `nil` for a heartbeat sent on
  /// request.
  public var sequenceCounter: UInt8?

  /// Creates a heartbeat.
  public init(interval: Double?, sequenceCounter: UInt8?) {
    self.interval = interval
    self.sequenceCounter = sequenceCounter
  }

  public init(decoding reader: inout MessageReader) {
    let milliseconds = reader.readUInt16()
    interval = milliseconds == 0xffff ? nil : Double(milliseconds) / 1000
    sequenceCounter = reader.readOptionalUInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    let milliseconds = interval.map { ($0 * 1000).rounded() }
    switch milliseconds {
    case nil: writer.appendUInt16(0xffff)
    case let value? where value >= 0 && value <= 0xffff: writer.appendUInt16(UInt16(value))
    default: writer.appendUInt16(0xfffe)
    }
    writer.appendUInt8(sequenceCounter)
    writer.appendUInt8(0xff)
    writer.appendUInt32(0xffff_ffff)
  }
}
