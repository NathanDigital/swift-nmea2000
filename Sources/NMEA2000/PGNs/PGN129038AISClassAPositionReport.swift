// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129038, AIS class A position report.
///
/// Ports `SetN2kPGN129038` / `ParseN2kPGN129038`.
public struct AISClassAPositionReport: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129038
  public static let defaultPriority: UInt8 = 4

  /// The AIS message ID. Only the low six bits are sent.
  public var messageID: UInt8

  /// How many times the message has been repeated.
  public var repeatIndicator: AISRepeatIndicator

  /// The MMSI of the reporting station.
  public var userID: UInt32

  /// The latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// The position accuracy flag: `true` for high accuracy.
  public var isPositionAccurate: Bool

  /// A Boolean value that indicates whether receiver autonomous integrity monitoring is in use.
  public var isRAIMInUse: Bool

  /// The UTC second when the position was determined. Only the low six bits are sent.
  public var timestampSecond: UInt8

  /// The course over ground, in radians, or `nil` if not available.
  public var courseOverGround: Double?

  /// The speed over ground, in meters per second, or `nil` if not available.
  public var speedOverGround: Double?

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The true heading, in radians, or `nil` if not available.
  public var heading: Double?

  /// The rate of turn, in radians per second, or `nil` if not available.
  public var rateOfTurn: Double?

  /// The navigational status.
  public var navigationStatus: AISNavigationStatus

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// Creates an AIS class A position report message.
  ///
  /// The default matches upstream's `SetN2kPGN129038`.
  public init(
    messageID: UInt8,
    repeatIndicator: AISRepeatIndicator,
    userID: UInt32,
    latitude: Double?,
    longitude: Double?,
    isPositionAccurate: Bool,
    isRAIMInUse: Bool,
    timestampSecond: UInt8,
    courseOverGround: Double?,
    speedOverGround: Double?,
    transceiverInformation: AISTransceiverInformation,
    heading: Double?,
    rateOfTurn: Double?,
    navigationStatus: AISNavigationStatus,
    sequenceID: UInt8? = nil
  ) {
    self.messageID = messageID
    self.repeatIndicator = repeatIndicator
    self.userID = userID
    self.latitude = latitude
    self.longitude = longitude
    self.isPositionAccurate = isPositionAccurate
    self.isRAIMInUse = isRAIMInUse
    self.timestampSecond = timestampSecond
    self.courseOverGround = courseOverGround
    self.speedOverGround = speedOverGround
    self.transceiverInformation = transceiverInformation
    self.heading = heading
    self.rateOfTurn = rateOfTurn
    self.navigationStatus = navigationStatus
    self.sequenceID = sequenceID
  }

  public init(from reader: inout MessageReader) {
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
    courseOverGround = reader.readUInt16(resolution: 1e-04)
    speedOverGround = reader.readUInt16(resolution: 0.01)
    reader.skip(2)  // Communication state.
    transceiverInformation = AISTransceiverInformation(rawValue: (reader.readUInt8() >> 3) & 0x1f)
    heading = reader.readUInt16(resolution: 1e-04)
    rateOfTurn = reader.readInt16(resolution: 3.125e-05)
    navigationStatus = AISNavigationStatus(rawValue: reader.readUInt8() & 0x0f)
    _ = reader.readUInt8()  // Reserved.
    sequenceID = reader.readOptionalUInt8()
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(userID)
    writer.appendInt32(longitude, resolution: 1e-07)
    writer.appendInt32(latitude, resolution: 1e-07)
    writer.appendUInt8(
      (timestampSecond & 0x3f) << 2 | (isRAIMInUse ? 0x02 : 0) | (isPositionAccurate ? 0x01 : 0))
    writer.appendUInt16(courseOverGround, resolution: 1e-04)
    writer.appendUInt16(speedOverGround, resolution: 0.01)
    // 19 bits of communication state (all ones), then the transceiver information.
    writer.appendInt24(0x07_ffff | Int32(transceiverInformation.rawValue & 0x1f) << 19)
    writer.appendUInt16(heading, resolution: 1e-04)
    writer.appendInt16(rateOfTurn, resolution: 3.125e-05)
    writer.appendUInt8(0xf0 | navigationStatus.rawValue & 0x0f)
    writer.appendUInt8(0xfc)
    writer.appendUInt8(sequenceID)
  }
}
