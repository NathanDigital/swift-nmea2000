// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130576, trim tab status.
///
/// Ports `SetN2kPGN130576` / `ParseN2kPGN130576`.
public struct TrimTabStatus: ParameterGroup {
  public static let pgn: UInt32 = 130576
  public static let defaultPriority: UInt8 = 2

  /// The port trim tab position, in percent, or `nil` if not available.
  public var portTrimTab: Int8?

  /// The starboard trim tab position, in percent, or `nil` if not available.
  public var starboardTrimTab: Int8?

  /// Creates a trim tab status message.
  public init(
    portTrimTab: Int8? = nil,
    starboardTrimTab: Int8? = nil
  ) {
    self.portTrimTab = portTrimTab
    self.starboardTrimTab = starboardTrimTab
  }

  public init(decoding reader: inout MessageReader) {
    portTrimTab = reader.readOptionalInt8()
    starboardTrimTab = reader.readOptionalInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendInt8(portTrimTab)
    writer.appendInt8(starboardTrimTab)
    writer.appendUInt16(0xffff)
    writer.appendUInt32(0xffff_ffff)
  }
}
