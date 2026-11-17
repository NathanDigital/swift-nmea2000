// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126464, PGN list: the PGNs a device transmits, or those it receives.
///
/// ``Node`` sends both lists when asked for this PGN.
///
/// Ports `SetN2kPGN126464` and its transmit and receive variants.
public struct PGNList: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 126464
  public static let defaultPriority: UInt8 = 6

  /// Which of a device's lists a PGN list is (upstream's `tN2kPGNList`).
  public struct Kind: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    /// The value as it appears on the wire.
    public var rawValue: UInt8

    /// Creates a value from its wire representation.
    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// The PGNs the device transmits.
    public static let transmit = Self(rawValue: 0)

    /// The PGNs the device receives.
    public static let receive = Self(rawValue: 1)

    public var description: String {
      switch self {
      case .transmit: "transmit"
      case .receive: "receive"
      default: "unknown (\(rawValue))"
      }
    }
  }

  /// Whether this is the transmit or the receive list.
  public var kind: Kind

  /// The PGNs in the list.
  public var pgns: [UInt32]

  /// Creates a PGN list.
  public init(kind: Kind, pgns: [UInt32]) {
    self.kind = kind
    self.pgns = pgns
  }

  /// Ignores a trailing partial PGN.
  public init(from reader: inout MessageReader) {
    kind = Kind(rawValue: reader.readUInt8())
    pgns = []
    while reader.remainingCount >= 3 { pgns.append(reader.readUInt24()) }
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(kind.rawValue)
    for pgn in pgns { writer.appendInt24(Int32(truncatingIfNeeded: pgn)) }
  }
}
