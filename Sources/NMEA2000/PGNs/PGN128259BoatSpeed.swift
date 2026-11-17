// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128259, speed: speed through water and over ground.
///
/// Ports `SetN2kPGN128259` / `ParseN2kPGN128259`.
public struct BoatSpeed: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 128259
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The speed through water, in meters per second, or `nil` if not available.
  public var waterReferenced: Double?

  /// The speed over ground, in meters per second, or `nil` if not available.
  public var groundReferenced: Double?

  /// The kind of sensor that measures speed through water. Upstream writes the whole byte but reads
  /// back only the low four bits, so ``SpeedWaterReferenceType/error`` and
  /// ``SpeedWaterReferenceType/unavailable`` decode as 14 and 15.
  public var referenceType: SpeedWaterReferenceType

  /// Creates a speed message.
  public init(
    sequenceID: UInt8?,
    waterReferenced: Double?,
    groundReferenced: Double?,
    referenceType: SpeedWaterReferenceType
  ) {
    self.sequenceID = sequenceID
    self.waterReferenced = waterReferenced
    self.groundReferenced = groundReferenced
    self.referenceType = referenceType
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    waterReferenced = reader.readUInt16(resolution: 0.01)
    groundReferenced = reader.readUInt16(resolution: 0.01)
    referenceType = SpeedWaterReferenceType(rawValue: reader.readUInt8() & 0x0f)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(waterReferenced, resolution: 0.01)
    writer.appendUInt16(groundReferenced, resolution: 0.01)
    writer.appendUInt8(referenceType.rawValue)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
