// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 59904, ISO request: asks one device, or every device, to send a PGN.
///
/// ``Node`` answers requests for the network management PGNs itself.
///
/// Ports `SetN2kPGN59904` / `ParseN2kPGN59904`.
public struct ISORequest: ParameterGroup {
  public static let pgn: UInt32 = 59904
  public static let defaultPriority: UInt8 = 6

  /// The PGN being requested.
  public var requestedPGN: UInt32

  /// Creates a request. Send it to one device, or broadcast it to ask every
  /// device.
  public init(requestedPGN: UInt32) {
    self.requestedPGN = requestedPGN
  }

  /// - Throws: ``MessageDecodingError/invalidPayload(pgn:reason:)`` if the
  ///   payload isn't 3 to 8 bytes long, as upstream requires.
  public init(decoding reader: inout MessageReader) throws(MessageDecodingError) {
    guard (3...8).contains(reader.remainingCount) else {
      throw .invalidPayload(pgn: Self.pgn, reason: "an ISO request is 3 to 8 bytes long")
    }
    requestedPGN = reader.readUInt24()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendInt24(Int32(truncatingIfNeeded: requestedPGN))
  }
}
