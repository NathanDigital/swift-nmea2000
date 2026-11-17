// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127258, magnetic variation.
///
/// Ports `SetN2kPGN127258` / `ParseN2kPGN127258`.
public struct MagneticVariation: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127258
  public static let defaultPriority: UInt8 = 6

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The source of the variation.
  public var source: MagneticVariationSource

  /// The date the variation applies to, in days since 1970-01-01, or `nil` if not available.
  public var daysSince1970: UInt16?

  /// The magnetic variation, in radians, positive east, or `nil` if not available.
  public var variation: Double?

  /// Creates a magnetic variation message.
  public init(
    sequenceID: UInt8?,
    source: MagneticVariationSource,
    daysSince1970: UInt16?,
    variation: Double?
  ) {
    self.sequenceID = sequenceID
    self.source = source
    self.daysSince1970 = daysSince1970
    self.variation = variation
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    source = MagneticVariationSource(rawValue: reader.readUInt8() & 0x0f)
    daysSince1970 = reader.readOptionalUInt16()
    variation = reader.readInt16(resolution: 0.0001)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(source.rawValue & 0x0f)
    writer.appendUInt16(daysSince1970)
    writer.appendInt16(variation, resolution: 0.0001)
    writer.appendUInt16(0xffff)
  }
}
