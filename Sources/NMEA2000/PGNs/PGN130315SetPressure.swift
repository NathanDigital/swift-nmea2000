// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130315, set pressure.
///
/// Ports `SetN2kPGN130315`. Upstream has no parser for this PGN;
/// ``init(from:)`` decodes exactly what upstream's encoder writes.
public struct SetPressure: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 130315
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The pressure instance.
  public var instance: UInt8

  /// What the pressure represents.
  public var source: PressureSource

  /// The target pressure, in pascals, or `nil` if not available.
  public var setPressure: Double?

  /// Creates a set pressure message.
  public init(
    sequenceID: UInt8?,
    instance: UInt8,
    source: PressureSource,
    setPressure: Double?
  ) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.source = source
    self.setPressure = setPressure
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    source = PressureSource(rawValue: reader.readUInt8())
    setPressure = reader.readInt32(resolution: 0.1)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(source.rawValue)
    writer.appendInt32(setPressure, resolution: 0.1)
    writer.appendUInt8(0xff)
  }
}
