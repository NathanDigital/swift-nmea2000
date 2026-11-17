// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126996, product information: the device's model, software version,
/// serial code and NMEA 2000 certification.
///
/// ``Node`` sends its own when asked.
///
/// Ports `SetN2kPGN126996` / `ParseN2kPGN126996`.
public struct ProductInformation: ParameterGroup {
  public static let pgn: UInt32 = 126996
  public static let defaultPriority: UInt8 = 6

  /// The width of each string field, in bytes (`Max_N2kModelID_len` and its
  /// siblings).
  public static let stringFieldCount = 32

  /// The version of the NMEA 2000 database the device implements, times 1000
  /// (2101 for version 2.101).
  public var nmea2000Version: UInt16

  /// The manufacturer's product code.
  public var productCode: UInt16

  /// The model name. Only the first 32 bytes of UTF-8 are sent.
  public var modelID: String

  /// The software version. Only the first 32 bytes of UTF-8 are sent.
  public var softwareVersion: String

  /// The model version. Only the first 32 bytes of UTF-8 are sent.
  public var modelVersion: String

  /// The serial code. Only the first 32 bytes of UTF-8 are sent.
  public var modelSerialCode: String

  /// The NMEA 2000 certification level.
  public var certificationLevel: UInt8

  /// The current the device draws from the bus, as a load equivalency
  /// number: units of 50 mA. ``loadCurrent`` gives it in amperes.
  public var loadEquivalency: UInt8

  /// The current the device draws from the bus, in amperes.
  public var loadCurrent: Double { Double(loadEquivalency) * 0.05 }

  /// The product information upstream gives a device that doesn't set its
  /// own: NMEA 2000 version 2.101, product code 666 and model "Arduino
  /// N2k->PC". Set your own before connecting to a real bus.
  public static let `default` = ProductInformation(
    nmea2000Version: 2101, productCode: 666, modelID: "Arduino N2k->PC", softwareVersion: "1.0.0.0",
    modelVersion: "1.0.0", modelSerialCode: "00000001", certificationLevel: 0, loadEquivalency: 1)

  /// Creates product information.
  public init(
    nmea2000Version: UInt16,
    productCode: UInt16,
    modelID: String,
    softwareVersion: String,
    modelVersion: String,
    modelSerialCode: String,
    certificationLevel: UInt8 = 1,
    loadEquivalency: UInt8 = 1
  ) {
    self.nmea2000Version = nmea2000Version
    self.productCode = productCode
    self.modelID = modelID
    self.softwareVersion = softwareVersion
    self.modelVersion = modelVersion
    self.modelSerialCode = modelSerialCode
    self.certificationLevel = certificationLevel
    self.loadEquivalency = loadEquivalency
  }

  public init(decoding reader: inout MessageReader) {
    nmea2000Version = reader.readUInt16()
    productCode = reader.readUInt16()
    modelID = reader.readFixedString(count: Self.stringFieldCount) ?? ""
    softwareVersion = reader.readFixedString(count: Self.stringFieldCount) ?? ""
    modelVersion = reader.readFixedString(count: Self.stringFieldCount) ?? ""
    modelSerialCode = reader.readFixedString(count: Self.stringFieldCount) ?? ""
    certificationLevel = reader.readUInt8()
    loadEquivalency = reader.readUInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(nmea2000Version)
    writer.appendUInt16(productCode)
    writer.appendFixedString(modelID, count: Self.stringFieldCount)
    writer.appendFixedString(softwareVersion, count: Self.stringFieldCount)
    writer.appendFixedString(modelVersion, count: Self.stringFieldCount)
    writer.appendFixedString(modelSerialCode, count: Self.stringFieldCount)
    writer.appendUInt8(certificationLevel)
    writer.appendUInt8(loadEquivalency)
  }
}
