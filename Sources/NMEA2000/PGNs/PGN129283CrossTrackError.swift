// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129283, cross-track error.
///
/// Ports `SetN2kPGN129283` / `ParseN2kPGN129283`.
public struct CrossTrackError: ParameterGroup {
  public static let pgn: UInt32 = 129283
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The mode the error was calculated in.
  public var mode: CrossTrackErrorMode

  /// A Boolean value that indicates whether navigation has terminated, or
  /// `nil` if not available.
  ///
  /// The field is two bits wide. Upstream decodes only bit 0, so it reads
  /// error and not available as `true`; this type decodes both as `nil`,
  /// and sends `nil` as not available, which upstream's `bool` can't.
  public var isNavigationTerminated: Bool?

  /// The distance from the planned track, in meters, or `nil` if not available.
  public var crossTrackError: Double?

  /// Creates a cross-track error message.
  public init(
    sequenceID: UInt8?,
    mode: CrossTrackErrorMode,
    isNavigationTerminated: Bool?,
    crossTrackError: Double?
  ) {
    self.sequenceID = sequenceID
    self.mode = mode
    self.isNavigationTerminated = isNavigationTerminated
    self.crossTrackError = crossTrackError
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    let flags = reader.readUInt8()
    mode = CrossTrackErrorMode(rawValue: flags & 0x0f)
    isNavigationTerminated = Bool(twoBitFlag: flags >> 6)
    crossTrackError = reader.readInt32(resolution: 0.01)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(mode.rawValue | isNavigationTerminated.twoBitFlag << 6)
    writer.appendInt32(crossTrackError, resolution: 0.01)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
