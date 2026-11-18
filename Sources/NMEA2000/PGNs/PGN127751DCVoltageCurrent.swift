// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127751, DC voltage and current.
///
/// Ports `SetN2kPGN127751` / `ParseN2kPGN127751`. Negative currents decode correctly here, unlike
/// upstream; see `readInt24(resolution:)`.
public struct DCVoltageCurrent: ParameterGroup {
  public static let pgn: UInt32 = 127751
  public static let defaultPriority: UInt8 = 6

  /// The DC connection instance.
  public var instance: UInt8

  /// The potential, in volts, or `nil` if not available.
  public var voltage: Double?

  /// The current, in amperes, or `nil` if not available.
  public var current: Double?

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// Creates a DC voltage and current message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kDCVoltageCurrent`, including its sequence identifier of
  /// 1.
  public init(
    instance: UInt8,
    voltage: Double? = nil,
    current: Double? = nil,
    sequenceID: UInt8? = 1
  ) {
    self.instance = instance
    self.voltage = voltage
    self.current = current
    self.sequenceID = sequenceID
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    voltage = reader.readInt16(resolution: 0.1)
    current = reader.readInt24(resolution: 0.01)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendInt16(voltage, resolution: 0.1)
    writer.appendInt24(current, resolution: 0.01)
    writer.appendUInt8(0xff)
    writer.appendUInt8(0xff)
  }
}
