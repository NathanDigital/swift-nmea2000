// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129041, AIS aids to navigation report.
///
/// Ports `SetN2kPGN129041` / `ParseN2kPGN129041`. Upstream's `tN2kAISAtoNReportData` becomes this
/// type's properties.
public struct AISAtoNReport: ParameterGroup {
  public static let pgn: UInt32 = 129041
  public static let defaultPriority: UInt8 = 4

  /// The longest name upstream sends, in characters (20 plus 14 extended).
  public static let maxNameLength = 34

  /// The AIS message ID. Only the low six bits are sent.
  public var messageID: UInt8

  /// How many times the message has been repeated.
  public var repeatIndicator: AISRepeatIndicator

  /// The MMSI of the reporting station.
  public var userID: UInt32

  /// The longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// The latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The position accuracy flag: `true` for high accuracy.
  public var isPositionAccurate: Bool

  /// A Boolean value that indicates whether receiver autonomous integrity monitoring is in use.
  public var isRAIMInUse: Bool

  /// The UTC second when the position was determined. Only the low six bits are sent.
  public var timestampSecond: UInt8

  /// The length of the aid, in metres, or `nil` if not available.
  public var length: Double?

  /// The beam of the aid, in metres, or `nil` if not available.
  public var beam: Double?

  /// The distance of the position reference point from starboard, in metres, or `nil` if not
  /// available.
  public var positionReferenceStarboard: Double?

  /// The distance of the position reference point from true north, in metres, or `nil` if not
  /// available.
  public var positionReferenceTrueNorth: Double?

  /// The type of aid to navigation.
  public var atonType: AISAtoNType

  /// The off-position indicator.
  public var isOffPosition: Bool

  /// The virtual aid-to-navigation flag.
  public var isVirtual: Bool

  /// The assigned mode flag.
  public var isAssignedMode: Bool

  /// The type of electronic position fixing device.
  public var gnssType: GNSSType

  /// The aid-to-navigation status byte.
  public var atonStatus: UInt8

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The name of the aid.
  ///
  /// Upstream stores it in a buffer of ``maxNameLength`` UTF-8 bytes, so at most that many bytes
  /// are sent, with each non-ASCII character then replaced by `?`.
  public var name: String

  /// Creates an AIS aids to navigation report message.
  ///
  /// Defaults that aren't `nil` match the initial values of upstream's `tN2kAISAtoNReportData`.
  public init(
    messageID: UInt8 = 0xff,
    repeatIndicator: AISRepeatIndicator = .initial,
    userID: UInt32 = 0xffff_ffff,
    longitude: Double? = nil,
    latitude: Double? = nil,
    isPositionAccurate: Bool = false,
    isRAIMInUse: Bool = false,
    timestampSecond: UInt8 = 0xff,
    length: Double? = nil,
    beam: Double? = nil,
    positionReferenceStarboard: Double? = nil,
    positionReferenceTrueNorth: Double? = nil,
    atonType: AISAtoNType = .notSpecified,
    isOffPosition: Bool = false,
    isVirtual: Bool = false,
    isAssignedMode: Bool = false,
    gnssType: GNSSType = .gps,
    atonStatus: UInt8 = 0xff,
    transceiverInformation: AISTransceiverInformation = .channelAReception,
    name: String = ""
  ) {
    self.messageID = messageID
    self.repeatIndicator = repeatIndicator
    self.userID = userID
    self.longitude = longitude
    self.latitude = latitude
    self.isPositionAccurate = isPositionAccurate
    self.isRAIMInUse = isRAIMInUse
    self.timestampSecond = timestampSecond
    self.length = length
    self.beam = beam
    self.positionReferenceStarboard = positionReferenceStarboard
    self.positionReferenceTrueNorth = positionReferenceTrueNorth
    self.atonType = atonType
    self.isOffPosition = isOffPosition
    self.isVirtual = isVirtual
    self.isAssignedMode = isAssignedMode
    self.gnssType = gnssType
    self.atonStatus = atonStatus
    self.transceiverInformation = transceiverInformation
    self.name = name
  }

  public init(decoding reader: inout MessageReader) {
    let header = reader.readUInt8()
    messageID = header & 0x3f
    repeatIndicator = AISRepeatIndicator(rawValue: (header >> 6) & 0x03)
    userID = reader.readUInt32()
    longitude = reader.readInt32(resolution: 1e-07)
    latitude = reader.readInt32(resolution: 1e-07)
    let flags = reader.readUInt8()
    isPositionAccurate = flags & 0x01 != 0
    isRAIMInUse = flags & 0x02 != 0
    timestampSecond = (flags >> 2) & 0x3f
    length = reader.readUInt16(resolution: 0.1)
    beam = reader.readUInt16(resolution: 0.1)
    positionReferenceStarboard = reader.readUInt16(resolution: 0.1)
    positionReferenceTrueNorth = reader.readUInt16(resolution: 0.1)
    let atonFlags = reader.readUInt8()
    atonType = AISAtoNType(rawValue: atonFlags & 0x1f)
    isOffPosition = atonFlags & 0x20 != 0
    isVirtual = atonFlags & 0x40 != 0
    isAssignedMode = atonFlags & 0x80 != 0
    gnssType = GNSSType(rawValue: (reader.readUInt8() >> 1) & 0x0f)
    atonStatus = reader.readUInt8()
    transceiverInformation = AISTransceiverInformation(rawValue: reader.readUInt8() & 0x1f)
    name = reader.readVariableString(terminator: UInt8(ascii: "@")) ?? ""
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(userID)
    writer.appendInt32(longitude, resolution: 1e-07)
    writer.appendInt32(latitude, resolution: 1e-07)
    writer.appendUInt8(
      (timestampSecond & 0x3f) << 2 | (isRAIMInUse ? 0x02 : 0) | (isPositionAccurate ? 0x01 : 0))
    writer.appendUInt16(length, resolution: 0.1)
    writer.appendUInt16(beam, resolution: 0.1)
    writer.appendUInt16(positionReferenceStarboard, resolution: 0.1)
    writer.appendUInt16(positionReferenceTrueNorth, resolution: 0.1)
    writer.appendUInt8(
      (isAssignedMode ? 0x80 : 0) | (isVirtual ? 0x40 : 0) | (isOffPosition ? 0x20 : 0)
        | atonType.rawValue & 0x1f)
    writer.appendUInt8((gnssType.rawValue & 0x0f) << 1 | 0xe0)
    writer.appendUInt8(atonStatus)
    writer.appendUInt8(transceiverInformation.rawValue & 0x1f | 0xe0)
    // Upstream holds the name in a 34-byte buffer before encoding it.
    writer.appendVariableString(
      name.prefix(utf8ByteCount: Self.maxNameLength), maxLength: Self.maxNameLength,
      encoding: .asciiOnly)
  }
}
