// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126998, configuration information: free text about how a device is
/// installed, and from its manufacturer.
///
/// ``Node`` sends its own when asked.
///
/// Ports `SetN2kPGN126998` / `ParseN2kPGN126998`.
public struct ConfigurationInformation: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 126998
  public static let defaultPriority: UInt8 = 6

  /// The longest each field may be, in bytes
  /// (`Max_N2kConfigurationInfoField_len`).
  public static let maxFieldLength = 71

  /// The manufacturer's information, such as a contact address.
  public var manufacturerInformation: String

  /// The first line of the installation description.
  public var installationDescription1: String

  /// The second line of the installation description.
  public var installationDescription2: String

  /// Creates configuration information. Each field is cut to 71 bytes, or
  /// fewer if it has to be sent as UCS-2.
  public init(
    manufacturerInformation: String,
    installationDescription1: String,
    installationDescription2: String
  ) {
    self.manufacturerInformation = manufacturerInformation
    self.installationDescription1 = installationDescription1
    self.installationDescription2 = installationDescription2
  }

  public init(from reader: inout MessageReader) {
    installationDescription1 = reader.readVariableString() ?? ""
    installationDescription2 = reader.readVariableString() ?? ""
    manufacturerInformation = reader.readVariableString() ?? ""
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendVariableString(installationDescription1, maxLength: Self.maxFieldLength)
    writer.appendVariableString(installationDescription2, maxLength: Self.maxFieldLength)
    writer.appendVariableString(manufacturerInformation, maxLength: Self.maxFieldLength)
  }
}
