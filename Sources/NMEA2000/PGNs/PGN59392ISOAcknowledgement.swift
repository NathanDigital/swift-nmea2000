// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 59392, ISO acknowledgement: a reply to an ISO request or a group
/// function, sent to the requester.
///
/// ``Node`` sends a negative acknowledgement (control 1) for an addressed
/// ISO request it can't answer.
///
/// Ports `SetN2kPGN59392` / `SetN2kPGNISOAcknowledgement`.
public struct ISOAcknowledgement: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 59392
  public static let defaultPriority: UInt8 = 6

  /// The control byte: 0 acknowledges and 1 is a negative acknowledgement,
  /// the value upstream sends.
  public var control: UInt8

  /// The group function code being answered, or `0xff` for an ISO request.
  public var groupFunction: UInt8

  /// The PGN of the request being answered.
  public var pgn: UInt32

  /// Creates an acknowledgement.
  public init(control: UInt8, groupFunction: UInt8 = 0xff, pgn: UInt32) {
    self.control = control
    self.groupFunction = groupFunction
    self.pgn = pgn
  }

  public init(from reader: inout MessageReader) {
    control = reader.readUInt8()
    groupFunction = reader.readUInt8()
    reader.skip(3)
    pgn = reader.readUInt24()
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(control)
    writer.appendUInt8(groupFunction)
    for _ in 0..<3 { writer.appendUInt8(0xff) }
    writer.appendInt24(Int32(truncatingIfNeeded: pgn))
  }
}
