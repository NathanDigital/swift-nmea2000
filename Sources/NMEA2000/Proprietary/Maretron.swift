// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The proprietary header that starts every Maretron message: manufacturer
/// code 137, reserved bits and the marine industry code
/// (`MaretronProprietary`).
private let maretronHeader: UInt16 = 0x9889

extension MessageReader {
  /// Reads and checks a Maretron header.
  fileprivate mutating func readMaretronHeader(pgn: UInt32) throws(MessageDecodingError) {
    let header = readUInt16()
    guard header == maretronHeader else {
      throw .unexpectedProprietaryHeader(pgn: pgn, header: header, expected: maretronHeader)
    }
  }
}

/// PGN 130823, a high-range temperature from a Maretron TMP100.
///
/// Decoding throws ``MessageDecodingError/unexpectedProprietaryHeader(pgn:header:expected:)`` for a
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
    instance: UInt8, source: TemperatureSource, sequenceID: UInt8? = nil,
    actualTemperature: Double? = nil,
    setTemperature: Double? = nil
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
/// Decoding throws ``MessageDecodingError/unexpectedProprietaryHeader(pgn:header:expected:)`` for a
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

  /// The flow rate, in litres per hour as upstream uses them, or `nil` if not
  /// available.
  public var flowRateLitresPerHour: Double?

  /// Creates a fluid flow rate message.
  public init(
    instance: UInt8, fluidType: FluidType, sequenceID: UInt8? = nil,
    flowRateLitresPerHour: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.fluidType = fluidType
    self.flowRateLitresPerHour = flowRateLitresPerHour
  }

  public init(decoding reader: inout MessageReader) throws(MessageDecodingError) {
    try reader.readMaretronHeader(pgn: Self.pgn)
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    fluidType = FluidType(rawValue: reader.readUInt8())
    flowRateLitresPerHour = reader.readInt24(resolution: 0.1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(maretronHeader)
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(fluidType.rawValue)
    writer.appendInt24(flowRateLitresPerHour, resolution: 0.1)
  }
}

/// PGN 65287, a trip volume from a Maretron FFM100.
///
/// Decoding throws ``MessageDecodingError/unexpectedProprietaryHeader(pgn:header:expected:)`` for a
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

  /// The volume used on the trip, in litres as upstream uses them, or `nil` if
  /// not available.
  public var volumeLitres: Double?

  /// Creates a trip volume message.
  public init(
    instance: UInt8, fluidType: FluidType, sequenceID: UInt8? = nil, volumeLitres: Double? = nil
  ) {
    self.sequenceID = sequenceID
    self.instance = instance
    self.fluidType = fluidType
    self.volumeLitres = volumeLitres
  }

  public init(decoding reader: inout MessageReader) throws(MessageDecodingError) {
    try reader.readMaretronHeader(pgn: Self.pgn)
    sequenceID = reader.readOptionalUInt8()
    instance = reader.readUInt8()
    fluidType = FluidType(rawValue: reader.readUInt8())
    volumeLitres = reader.readInt24(resolution: 1)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(maretronHeader)
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(instance)
    writer.appendUInt8(fluidType.rawValue)
    writer.appendInt24(volumeLitres, resolution: 1)
  }
}

extension ParameterGroupCatalog {
  /// The Maretron parameter groups.
  public static let maretron = ParameterGroupCatalog([
    MaretronTemperatureHighRange.self, MaretronFluidFlowRate.self, MaretronTripVolume.self,
  ])
}
