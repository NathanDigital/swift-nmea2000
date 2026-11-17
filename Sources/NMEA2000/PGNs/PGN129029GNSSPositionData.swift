// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129029, GNSS position data: a full position fix with time and quality.
///
/// Ports `SetN2kPGN129029` / `ParseN2kPGN129029`.
///
/// Upstream sends and reads at most one reference station. This type keeps a
/// list so that decoding can read every station the message declares, but
/// encoding sends only the first, as upstream does.
public struct GNSSPositionData: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129029
  public static let defaultPriority: UInt8 = 3

  /// A differential correction reference station.
  public struct ReferenceStation: Sendable, Hashable {
    /// The satellite systems the station provides corrections for.
    public var type: GNSSType

    /// The station identifier. Only the low 12 bits are sent.
    public var id: UInt16

    /// The age of the corrections, in seconds, or `nil` if not available.
    public var ageOfCorrection: Double?

    /// Creates a reference station.
    public init(type: GNSSType, id: UInt16, ageOfCorrection: Double?) {
      self.type = type
      self.id = id
      self.ageOfCorrection = ageOfCorrection
    }
  }

  /// The sequence identifier that ties together measurements taken at the same
  /// time, or `nil` if not available.
  public var sequenceID: UInt8?

  /// The date of the fix, in days since 1970-01-01, or `nil` if not available.
  public var daysSince1970: UInt16?

  /// The time of the fix, in seconds since midnight UTC, or `nil` if not
  /// available.
  public var secondsSinceMidnight: Double?

  /// The latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// The altitude above the WGS-84 ellipsoid, in meters, or `nil` if not
  /// available.
  public var altitude: Double?

  /// The satellite systems used for the fix.
  public var gnssType: GNSSType

  /// The method used to obtain the fix.
  public var method: GNSSMethod

  /// The number of satellites used, or `nil` if not available.
  public var satelliteCount: UInt8?

  /// The horizontal dilution of precision, or `nil` if not available.
  public var horizontalDilution: Double?

  /// The positional dilution of precision, or `nil` if not available.
  public var positionDilution: Double?

  /// The separation between the WGS-84 ellipsoid and mean sea level, in
  /// meters, or `nil` if not available.
  public var geoidalSeparation: Double?

  /// The reference stations used for differential corrections, or `nil` if
  /// not available.
  ///
  /// `nil` is sent as a station count of `0xff`; an empty list as `0`. Only
  /// the first station is sent, as upstream sends at most one.
  public var referenceStations: [ReferenceStation]?

  /// Creates a GNSS position data message.
  ///
  /// The defaults match upstream's `SetN2kPGN129029`, which sends 0 rather than "not available" for
  /// the positional dilution and geoidal separation.
  public init(
    sequenceID: UInt8?,
    daysSince1970: UInt16?,
    secondsSinceMidnight: Double?,
    latitude: Double?,
    longitude: Double?,
    altitude: Double?,
    gnssType: GNSSType,
    method: GNSSMethod,
    satelliteCount: UInt8?,
    horizontalDilution: Double?,
    positionDilution: Double? = 0,
    geoidalSeparation: Double? = 0,
    referenceStations: [ReferenceStation]? = []
  ) {
    self.sequenceID = sequenceID
    self.daysSince1970 = daysSince1970
    self.secondsSinceMidnight = secondsSinceMidnight
    self.latitude = latitude
    self.longitude = longitude
    self.altitude = altitude
    self.gnssType = gnssType
    self.method = method
    self.satelliteCount = satelliteCount
    self.horizontalDilution = horizontalDilution
    self.positionDilution = positionDilution
    self.geoidalSeparation = geoidalSeparation
    self.referenceStations = referenceStations
  }

  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    daysSince1970 = reader.readOptionalUInt16()
    secondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
    latitude = reader.readInt64(resolution: 1e-16)
    longitude = reader.readInt64(resolution: 1e-16)
    altitude = reader.readInt64(resolution: 1e-6)
    let types = reader.readUInt8()
    gnssType = GNSSType(rawValue: types & 0x0f)
    method = GNSSMethod(rawValue: (types >> 4) & 0x0f)
    _ = reader.readUInt8()  // Integrity (2 bits) and reserved bits.
    satelliteCount = reader.readOptionalUInt8()
    horizontalDilution = reader.readInt16(resolution: 0.01)
    positionDilution = reader.readInt16(resolution: 0.01)
    geoidalSeparation = reader.readInt32(resolution: 0.01)
    guard let count = reader.readOptionalUInt8() else {
      referenceStations = nil
      return
    }
    var stations: [ReferenceStation] = []
    while stations.count < count && reader.remainingCount > 0 {
      let typeAndID = reader.readUInt16()
      stations.append(
        ReferenceStation(
          type: GNSSType(rawValue: UInt8(typeAndID & 0x0f)),
          id: typeAndID >> 4,
          ageOfCorrection: reader.readUInt16(resolution: 0.01)))
    }
    referenceStations = stations
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt16(daysSince1970)
    writer.appendUInt32(secondsSinceMidnight, resolution: 0.0001)
    writer.appendInt64(latitude, resolution: 1e-16)
    writer.appendInt64(longitude, resolution: 1e-16)
    writer.appendInt64(altitude, resolution: 1e-6)
    writer.appendUInt8(gnssType.rawValue & 0x0f | (method.rawValue & 0x0f) << 4)
    writer.appendUInt8(1 | 0xfc)  // Integrity "safe", as upstream always sends.
    writer.appendUInt8(satelliteCount)
    writer.appendInt16(horizontalDilution, resolution: 0.01)
    writer.appendInt16(positionDilution, resolution: 0.01)
    writer.appendInt32(geoidalSeparation, resolution: 0.01)
    guard let referenceStations else {
      writer.appendUInt8(UInt8?.none)
      return
    }
    guard let station = referenceStations.first else {
      writer.appendUInt8(0)
      return
    }
    writer.appendUInt8(1)
    writer.appendUInt16(UInt16(station.type.rawValue & 0x0f) | station.id << 4)
    writer.appendUInt16(station.ageOfCorrection, resolution: 0.01)
  }
}
