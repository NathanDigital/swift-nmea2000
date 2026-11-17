// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 130074, waypoint list: waypoints from a waypoint database.
///
/// Ports `SetN2kPGN130074` / `AppendN2kPGN130074`. Upstream has no parser for
/// this PGN; ``init(from:)`` decodes exactly what upstream's encoder writes.
///
/// Upstream writes each name's UTF-8 bytes as an ASCII variable-length string
/// without a length limit, and writes an empty name as a single NUL character.
/// This type does the same.
public struct WaypointList: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 130074
  public static let defaultPriority: UInt8 = 7

  /// The index of the first waypoint in this message within the database.
  public var startIndex: UInt16

  /// The total number of waypoints in the database.
  public var waypointCount: UInt16

  /// The identifier of the waypoint database.
  public var database: UInt16

  /// The waypoints in this message.
  ///
  /// Encoding stops at the first waypoint that doesn't fit in the message, as
  /// upstream's `AppendN2kPGN130074` refuses it.
  public var waypoints: [Waypoint]

  /// Creates a waypoint list message.
  public init(
    startIndex: UInt16, waypointCount: UInt16, database: UInt16, waypoints: [Waypoint] = []
  ) {
    self.startIndex = startIndex
    self.waypointCount = waypointCount
    self.database = database
    self.waypoints = waypoints
  }

  public init(from reader: inout MessageReader) {
    startIndex = reader.readUInt16()
    let count = reader.readUInt16()
    waypointCount = reader.readUInt16()
    database = reader.readUInt16()
    reader.skip(2)  // Reserved.
    waypoints = []
    while waypoints.count < count && reader.remainingCount > 0 {
      waypoints.append(
        Waypoint(
          id: reader.readUInt16(),
          name: reader.readVariableString() ?? "",
          latitude: reader.readInt32(resolution: 1e-07),
          longitude: reader.readInt32(resolution: 1e-07)))
    }
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt16(startIndex)
    let countIndex = writer.count
    writer.appendUInt16(0)
    writer.appendUInt16(waypointCount)
    writer.appendUInt16(database)
    writer.appendUInt8(0xff)  // Reserved.
    writer.appendUInt8(0xff)  // Reserved.

    var count: UInt16 = 0
    for waypoint in waypoints {
      let name = Array(waypoint.name.utf8.prefix { $0 != 0 })
      let entryLength = name.isEmpty ? 13 : 12 + name.count
      guard writer.count + entryLength < Message.maxDataCount else { break }
      count += 1
      writer.setUInt16(count, at: countIndex)
      writer.appendUInt16(waypoint.id)
      if name.isEmpty {
        writer.appendBytes([0x03, 0x01, 0x00])
      } else {
        writer.appendUInt8(UInt8(name.count + 2))
        writer.appendUInt8(0x01)
        writer.appendBytes(name)
      }
      writer.appendInt32(waypoint.latitude, resolution: 1e-07)
      writer.appendInt32(waypoint.longitude, resolution: 1e-07)
    }
  }
}
