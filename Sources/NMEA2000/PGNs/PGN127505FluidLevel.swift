// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127505, fluid level.
///
/// Ports `SetN2kPGN127505` / `ParseN2kPGN127505`.
public struct FluidLevel: ParameterGroup {
  public static let pgn: UInt32 = 127505
  public static let defaultPriority: UInt8 = 6

  /// The tank instance. Only the low four bits are sent.
  public var instance: UInt8

  /// The fluid the tank holds.
  public var fluidType: FluidType

  /// The tank level, in percent of full, or `nil` if not available.
  public var level: Double?

  /// The tank capacity, in litres as upstream uses them, or `nil` if not available.
  public var capacityLitres: Double?

  /// Creates a fluid level message.
  public init(
    instance: UInt8,
    fluidType: FluidType,
    level: Double? = nil,
    capacityLitres: Double? = nil
  ) {
    self.instance = instance
    self.fluidType = fluidType
    self.level = level
    self.capacityLitres = capacityLitres
  }

  public init(decoding reader: inout MessageReader) {
    let instanceAndType = reader.readUInt8()
    instance = instanceAndType & 0x0f
    fluidType = FluidType(rawValue: (instanceAndType >> 4) & 0x0f)
    level = reader.readInt16(resolution: 0.004)
    capacityLitres = reader.readUInt32(resolution: 0.1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance & 0x0f | (fluidType.rawValue & 0x0f) << 4)
    writer.appendInt16(level, resolution: 0.004)
    writer.appendUInt32(capacityLitres, resolution: 0.1)
    writer.appendUInt8(0xff)
  }
}
