// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The proprietary header that starts every Maretron message: manufacturer
/// code 137, reserved bits and the marine industry code
/// (`MaretronProprietary`).
let maretronHeader: UInt16 = 0x9889

extension MessageReader {
  /// Reads and checks a Maretron header.
  mutating func readMaretronHeader(pgn: UInt32) throws(MessageDecodingError) {
    guard readUInt16() == maretronHeader else {
      throw .invalidPayload(pgn: pgn, reason: "not a Maretron message")
    }
  }
}

/// PGN 130823, a high-range temperature from a Maretron TMP100.
///
/// Decoding throws ``MessageDecodingError/invalidPayload(pgn:reason:)`` for a
/// message without Maretron's header, as upstream rejects it.
///
/// Ports `SetN2kMaretronPGN130823` / `ParseN2kMaretronPGN130823`.
public struct MaretronTemperatureHighRange: ParameterGroup {
  public static let pgn: UInt32 = 130823
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier that ties together measurements taken at the
  /// same time, or `nil` if not available.
  public var sequenceID: UInt8?

  /// The temperature instance.
  public var instance: UInt8

  /// What the temperature represents.
  public var source: TemperatureSource

  /// The measured temperature, in kelvins, or `nil` if not available.
  public var actualTemperature: Double?

  /// The target temperature, in kelvins, or `nil` if not available.
  public var setTemperature: Double?

  /// Creates a high-range temperature message.
  public init(
    sequenceID: UInt8?, instance: UInt8, source: TemperatureSource, actualTemperature: Double?,
    setTemperature: Double?
  ) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.source = source
    self.actualTemperature = actualTemperature
    self.setTemperature = setTemperature
  }

  public init(decoding reader: inout MessageReader) throws(MessageDecodingError) {
    try reader.readMaretronHeader(pgn: Self.pgn)
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    source = TemperatureSource(rawValue: reader.readUInt8())
    actualTemperature = reader.readUInt16(resolution: 0.1)
    setTemperature = reader.readUInt16(resolution: 0.1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(maretronHeader)
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(source.rawValue)
    writer.appendUInt16(actualTemperature, resolution: 0.1)
    writer.appendUInt16(setTemperature, resolution: 0.1)
  }
}

/// PGN 65286, a fluid flow rate from a Maretron FFM100.
///
/// Decoding throws ``MessageDecodingError/invalidPayload(pgn:reason:)`` for a
/// message without Maretron's header, as upstream rejects it.
///
/// Ports `SetN2kMaretronPGN65286` / `ParseN2kMaretronPGN65286`.
public struct MaretronFluidFlowRate: ParameterGroup {
  public static let pgn: UInt32 = 65286
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// The flow rate instance.
  public var instance: UInt8

  /// The fluid being measured.
  public var fluidType: FluidType

  /// The flow rate, in litres per hour as upstream has it, or `nil` if not
  /// available.
  public var flowRate: Double?

  /// Creates a fluid flow rate message.
  public init(sequenceID: UInt8?, instance: UInt8, fluidType: FluidType, flowRate: Double?) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.fluidType = fluidType
    self.flowRate = flowRate
  }

  public init(decoding reader: inout MessageReader) throws(MessageDecodingError) {
    try reader.readMaretronHeader(pgn: Self.pgn)
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    fluidType = FluidType(rawValue: reader.readUInt8())
    flowRate = reader.readInt24(resolution: 0.1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(maretronHeader)
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(fluidType.rawValue)
    writer.appendInt24(flowRate, resolution: 0.1)
  }
}

/// PGN 65287, a trip volume from a Maretron FFM100.
///
/// Decoding throws ``MessageDecodingError/invalidPayload(pgn:reason:)`` for a
/// message without Maretron's header, as upstream rejects it.
///
/// Ports `SetN2kMaretronPGN65287` / `ParseN2kMaretronPGN65287`.
public struct MaretronTripVolume: ParameterGroup {
  public static let pgn: UInt32 = 65287
  public static let defaultPriority: UInt8 = 5

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// The volume instance.
  public var instance: UInt8

  /// The fluid being measured.
  public var fluidType: FluidType

  /// The volume used on the trip, in litres as upstream has it, or `nil` if
  /// not available.
  public var volume: Double?

  /// Creates a trip volume message.
  public init(sequenceID: UInt8?, instance: UInt8, fluidType: FluidType, volume: Double?) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.fluidType = fluidType
    self.volume = volume
  }

  public init(decoding reader: inout MessageReader) throws(MessageDecodingError) {
    try reader.readMaretronHeader(pgn: Self.pgn)
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    fluidType = FluidType(rawValue: reader.readUInt8())
    volume = reader.readInt24(resolution: 1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(maretronHeader)
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(fluidType.rawValue)
    writer.appendInt24(volume, resolution: 1)
  }
}
