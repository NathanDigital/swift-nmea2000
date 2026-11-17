// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127245, rudder: rudder position and angle order.
///
/// Ports `SetN2kPGN127245` / `ParseN2kPGN127245`.
public struct Rudder: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127245
  public static let defaultPriority: UInt8 = 2

  /// The rudder position, in radians, positive to starboard, or `nil` if not available.
  public var position: Double?

  /// The rudder instance.
  public var instance: UInt8

  /// The commanded rudder direction.
  public var directionOrder: RudderDirectionOrder

  /// The commanded rudder angle, in radians, or `nil` if not available.
  public var angleOrder: Double?

  /// Creates a rudder message.
  public init(
    position: Double?,
    instance: UInt8,
    directionOrder: RudderDirectionOrder,
    angleOrder: Double?
  ) {
    self.position = position
    self.instance = instance
    self.directionOrder = directionOrder
    self.angleOrder = angleOrder
  }

  public init(from reader: inout MessageReader) {
    instance = reader.readUInt8()
    directionOrder = RudderDirectionOrder(rawValue: reader.readUInt8() & 0x07)
    angleOrder = reader.readInt16(resolution: 0.0001)
    position = reader.readInt16(resolution: 0.0001)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt8(0xf8 | directionOrder.rawValue & 0x07)
    writer.appendInt16(angleOrder, resolution: 0.0001)
    writer.appendInt16(position, resolution: 0.0001)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
