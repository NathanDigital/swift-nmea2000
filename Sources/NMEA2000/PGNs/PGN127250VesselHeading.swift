// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127250, vessel heading: heading with deviation and variation.
///
/// Ports `SetN2kPGN127250` / `ParseN2kPGN127250`.
public struct VesselHeading: ParameterGroup {
  public static let pgn: UInt32 = 127250
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The heading, in radians, or `nil` if not available.
  public var heading: Double?

  /// The magnetic deviation, in radians, or `nil` if not available.
  public var deviation: Double?

  /// The magnetic variation, in radians, or `nil` if not available.
  public var variation: Double?

  /// Whether the heading is true or magnetic.
  public var reference: HeadingReference

  /// Creates a vessel heading message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kMagneticHeading`.
  public init(
    reference: HeadingReference,
    sequenceID: UInt8? = nil,
    heading: Double? = nil,
    deviation: Double? = nil,
    variation: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.heading = heading
    self.deviation = deviation
    self.variation = variation
    self.reference = reference
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    heading = reader.readUInt16(resolution: 0.0001)
    deviation = reader.readInt16(resolution: 0.0001)
    variation = reader.readInt16(resolution: 0.0001)
    reference = HeadingReference(rawValue: reader.readUInt8() & 0x03)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(heading, resolution: 0.0001)
    writer.appendInt16(deviation, resolution: 0.0001)
    writer.appendInt16(variation, resolution: 0.0001)
    writer.appendUInt8(0xfc | reference.rawValue)
  }
}
