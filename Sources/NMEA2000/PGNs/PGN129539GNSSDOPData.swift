// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129539, GNSS DOPs: dilution of precision.
///
/// Ports `SetN2kPGN129539` / `ParseN2kPGN129539`. Upstream names the parser `ParseN2kPgn129539`.
public struct GNSSDOPData: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129539
  public static let defaultPriority: UInt8 = 6

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The requested dimension mode.
  public var desiredMode: GNSSDOPMode

  /// The dimension mode in use.
  public var actualMode: GNSSDOPMode

  /// The horizontal dilution of precision, or `nil` if not available.
  public var horizontalDilution: Double?

  /// The vertical dilution of precision, or `nil` if not available.
  public var verticalDilution: Double?

  /// The time dilution of precision, or `nil` if not available.
  public var timeDilution: Double?

  /// Creates a GNSS DOPs message.
  public init(
    sequenceID: UInt8?,
    desiredMode: GNSSDOPMode,
    actualMode: GNSSDOPMode,
    horizontalDilution: Double?,
    verticalDilution: Double?,
    timeDilution: Double?
  ) {
    self.sequenceID = sequenceID
    self.desiredMode = desiredMode
    self.actualMode = actualMode
    self.horizontalDilution = horizontalDilution
    self.verticalDilution = verticalDilution
    self.timeDilution = timeDilution
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    let modes = reader.readUInt8()
    desiredMode = GNSSDOPMode(rawValue: modes & 0x07)
    actualMode = GNSSDOPMode(rawValue: (modes >> 3) & 0x07)
    horizontalDilution = reader.readInt16(resolution: 0.01)
    verticalDilution = reader.readInt16(resolution: 0.01)
    timeDilution = reader.readInt16(resolution: 0.01)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(0xc0 | (actualMode.rawValue & 0x07) << 3 | desiredMode.rawValue & 0x07)
    writer.appendInt16(horizontalDilution, resolution: 0.01)
    writer.appendInt16(verticalDilution, resolution: 0.01)
    writer.appendInt16(timeDilution, resolution: 0.01)
  }
}
