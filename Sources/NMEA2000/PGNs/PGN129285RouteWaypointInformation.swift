// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129285, route and waypoint information: a route and its waypoints.
///
/// Ports `SetN2kPGN129285` / `AppendN2kPGN129285`. Upstream has no parser for
/// this PGN; ``init(decoding:)`` decodes exactly what upstream's encoder writes.
public struct RouteWaypointInformation: ParameterGroup {
  public static let pgn: UInt32 = 129285
  public static let defaultPriority: UInt8 = 6

  /// The longest route or waypoint name upstream sends, in characters.
  public static let maxNameLength = 30

  /// The index of the first waypoint in this message within the route.
  public var startIndex: UInt16

  /// The identifier of the database holding the route.
  public var database: UInt16

  /// The identifier of the route.
  public var route: UInt16

  /// The direction the route is being navigated.
  public var navigationDirection: NavigationDirection

  /// The route's name. Only the first ``maxNameLength`` characters are sent.
  public var routeName: String

  /// Whether supplementary route data is available.
  public var supplementaryData: BinaryStatus

  /// The waypoints.
  ///
  /// Encoding stops at the first waypoint that doesn't fit in the message, as
  /// upstream's `AppendN2kPGN129285` refuses it. Names are truncated to
  /// ``maxNameLength`` characters.
  public var waypoints: [Waypoint]

  /// Creates a route and waypoint information message.
  ///
  /// The default supplementary data matches upstream's `SetN2kPGN129285`.
  public init(
    startIndex: UInt16,
    database: UInt16,
    route: UInt16,
    navigationDirection: NavigationDirection,
    routeName: String,
    supplementaryData: BinaryStatus = .no,
    waypoints: [Waypoint] = []
  ) {
    self.startIndex = startIndex
    self.database = database
    self.route = route
    self.navigationDirection = navigationDirection
    self.routeName = routeName
    self.supplementaryData = supplementaryData
    self.waypoints = waypoints
  }

  public init(decoding reader: inout MessageReader) {
    startIndex = reader.readUInt16()
    let count = reader.readUInt16()
    database = reader.readUInt16()
    route = reader.readUInt16()
    let flags = reader.readUInt8()
    navigationDirection = NavigationDirection(rawValue: flags & 0x07)
    supplementaryData = BinaryStatus(rawValue: (flags >> 3) & 0x03)
    routeName = reader.readVariableString() ?? ""
    _ = reader.readUInt8()  // Reserved.
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

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt16(startIndex)
    let countIndex = writer.count
    writer.appendUInt16(0)
    writer.appendUInt16(database)
    writer.appendUInt16(route)
    writer.appendUInt8(
      0xe0 | (supplementaryData.rawValue & 0x03) << 3 | navigationDirection.rawValue & 0x07)
    writer.appendVariableString(
      routeName, maxLength: Self.maxNameLength, encoding: .unicode, lengthUnit: .characters)
    writer.appendUInt8(0xff)  // Reserved.

    var count: UInt16 = 0
    for waypoint in waypoints {
      // Upstream's size estimate: 12 bytes plus the name's length in bytes.
      let nameLength = waypoint.name.utf8.prefix { $0 != 0 }.count
      guard writer.count + 12 + nameLength < Message.maxDataCount else { break }
      let start = writer.count
      writer.appendUInt16(waypoint.id)
      writer.appendVariableString(
        waypoint.name, maxLength: Self.maxNameLength, encoding: .unicode, lengthUnit: .characters)
      guard writer.count + 8 < Message.maxDataCount else {
        writer.truncate(to: start)
        break
      }
      writer.appendInt32(waypoint.latitude, resolution: 1e-07)
      writer.appendInt32(waypoint.longitude, resolution: 1e-07)
      count += 1
      writer.setUInt16(count, at: countIndex)
    }
  }
}
