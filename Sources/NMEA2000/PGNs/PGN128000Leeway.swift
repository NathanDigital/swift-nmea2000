// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128000, leeway angle.
///
/// Ports `SetN2kPGN128000` / `ParseN2kPGN128000`.
public struct Leeway: ParameterGroup {
  public static let pgn: UInt32 = 128000
  public static let defaultPriority: UInt8 = 4

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The leeway angle, in radians, positive when drifting to starboard, or `nil` if not available.
  public var leeway: Double?

  /// Creates a leeway angle message.
  public init(
    sequenceID: UInt8? = nil,
    leeway: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.leeway = leeway
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    leeway = reader.readInt16(resolution: 0.0001)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendInt16(leeway, resolution: 0.0001)
    for _ in 0..<5 { writer.appendUInt8(0xff) }
  }
}
