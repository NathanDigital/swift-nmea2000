// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128267, water depth.
///
/// Ports `SetN2kPGN128267` / `ParseN2kPGN128267`.
public struct WaterDepth: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 128267
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The depth below the transducer, in meters, or `nil` if not available.
  public var depthBelowTransducer: Double?

  /// The distance from the transducer to the waterline (positive) or keel (negative), in meters, or
  /// `nil` if not available.
  public var offset: Double?

  /// The maximum depth the sounder can measure, in meters, or `nil` if not available.
  public var range: Double?

  /// Creates a water depth message.
  ///
  /// The default matches upstream's `SetN2kPGN128267`.
  public init(
    sequenceID: UInt8?,
    depthBelowTransducer: Double?,
    offset: Double?,
    range: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.depthBelowTransducer = depthBelowTransducer
    self.offset = offset
    self.range = range
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    depthBelowTransducer = reader.readUInt32(resolution: 0.01)
    offset = reader.readInt16(resolution: 0.001)
    range = reader.readUInt8(resolution: 10)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt32(depthBelowTransducer, resolution: 0.01)
    writer.appendInt16(offset, resolution: 0.001)
    writer.appendUInt8(range, resolution: 10)
  }
}
