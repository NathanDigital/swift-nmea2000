// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 128259, speed: speed through water and over ground.
///
/// Ports `SetN2kPGN128259` / `ParseN2kPGN128259`.
public struct BoatSpeed: ParameterGroup {
  public static let pgn: UInt32 = 128259
  public static let defaultPriority: UInt8 = 2

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The speed through water, in metres per second, or `nil` if not available.
  public var waterReferenced: Double?

  /// The speed over ground, in metres per second, or `nil` if not available.
  public var groundReferenced: Double?

  /// The kind of sensor that measures speed through water.
  ///
  /// The field is four bits wide. ``SpeedWaterReferenceType/error`` (254) and
  /// ``SpeedWaterReferenceType/unavailable`` (255) are sent as the whole byte, as upstream sends
  /// them, so the reserved upper bits are set. On decode, the four-bit codes 14 and 15 map back to
  /// those values. Upstream decodes them as 14 and 15, which no longer equal its own constants.
  public var referenceType: SpeedWaterReferenceType

  /// Creates a speed message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kPGN128259`.
  public init(
    sequenceID: UInt8? = nil,
    waterReferenced: Double? = nil,
    groundReferenced: Double? = nil,
    referenceType: SpeedWaterReferenceType = .paddleWheel
  ) {
    self.sequenceID = sequenceID
    self.waterReferenced = waterReferenced
    self.groundReferenced = groundReferenced
    self.referenceType = referenceType
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    waterReferenced = reader.readUInt16(resolution: 0.01)
    groundReferenced = reader.readUInt16(resolution: 0.01)
    switch reader.readUInt8() & 0x0f {
    case 0x0e: referenceType = .error
    case 0x0f: referenceType = .unavailable
    case let code: referenceType = SpeedWaterReferenceType(rawValue: code)
    }
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(waterReferenced, resolution: 0.01)
    writer.appendUInt16(groundReferenced, resolution: 0.01)
    writer.appendUInt8(referenceType.rawValue)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
