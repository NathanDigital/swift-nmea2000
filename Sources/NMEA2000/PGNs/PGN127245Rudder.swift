// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127245, rudder: rudder position and angle order.
///
/// Ports `SetN2kPGN127245` / `ParseN2kPGN127245`.
public struct Rudder: ParameterGroup {
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
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kPGN127245`.
  public init(
    position: Double? = nil,
    instance: UInt8 = 0,
    directionOrder: RudderDirectionOrder = .noDirectionOrder,
    angleOrder: Double? = nil
  ) {
    self.position = position
    self.instance = instance
    self.directionOrder = directionOrder
    self.angleOrder = angleOrder
  }

  public init(decoding reader: inout MessageReader) {
    instance = reader.readUInt8()
    directionOrder = RudderDirectionOrder(rawValue: reader.readUInt8() & 0x07)
    angleOrder = reader.readInt16(resolution: 0.0001)
    position = reader.readInt16(resolution: 0.0001)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt8(0xf8 | directionOrder.rawValue & 0x07)
    writer.appendInt16(angleOrder, resolution: 0.0001)
    writer.appendInt16(position, resolution: 0.0001)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
