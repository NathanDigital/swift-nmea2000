// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 60928, ISO address claim: a device's NAME, sent from the address it
/// claims.
///
/// ``Node`` sends and answers address claims itself; decode this to follow
/// which device holds which address.
///
/// Ports `SetN2kPGN60928` and the NAME read in
/// `tNMEA2000::HandleISOAddressClaim`.
public struct ISOAddressClaim: ParameterGroup {
  public static let pgn: UInt32 = 60928
  public static let defaultPriority: UInt8 = 6

  /// The claiming device's NAME. A payload shorter than eight bytes decodes
  /// as all ones, as upstream reads it.
  public var name: DeviceName

  /// Creates an address claim.
  public init(name: DeviceName) {
    self.name = name
  }

  public init(decoding reader: inout MessageReader) {
    name = DeviceName(rawValue: reader.readUInt64())
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt64(name.rawValue)
  }
}
