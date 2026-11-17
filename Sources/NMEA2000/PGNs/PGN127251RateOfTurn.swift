// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127251, rate of turn.
///
/// Ports `SetN2kPGN127251` / `ParseN2kPGN127251`.
public struct RateOfTurn: ParameterGroup {
  public static let pgn: UInt32 = 127251
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The rate of turn, in radians per second, positive to starboard, or `nil` if not available.
  public var rate: Double?

  /// Creates a rate of turn message.
  public init(
    sequenceID: UInt8?,
    rate: Double?
  ) {
    self.sequenceID = sequenceID
    self.rate = rate
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    rate = reader.readInt32(resolution: 3.125e-08)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendInt32(rate, resolution: 3.125e-08)
    writer.appendUInt8(0xff)
    writer.appendUInt16(0xffff)
  }
}
