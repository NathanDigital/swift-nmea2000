// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129039, AIS class B position report.
///
/// Ports `SetN2kPGN129039` / `ParseN2kPGN129039`.
public struct AISClassBPositionReport: ParameterGroup {
  public static let pgn: UInt32 = 129039
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

  /// The speed over ground, in metres per second, or `nil` if not available.
  public var speedOverGround: Double?

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The true heading, in radians, or `nil` if not available.
  public var heading: Double?

  /// The class B unit type.
  public var unitType: AISUnitType

  /// The class B display flag.
  public var hasDisplay: Bool

  /// The class B DSC flag.
  public var hasDSC: Bool

  /// The class B band flag.
  public var canUseWholeBand: Bool

  /// The class B message 22 flag.
  public var acceptsMessage22: Bool

  /// The station operating mode.
  public var mode: AISMode

  /// The communication state selector flag.
  public var isCommunicationStateITDMA: Bool

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// Creates an AIS class B position report message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kPGN129039`.
  public init(
    messageID: UInt8,
    repeatIndicator: AISRepeatIndicator,
    userID: UInt32,
    isPositionAccurate: Bool,
    isRAIMInUse: Bool,
    timestampSecond: UInt8,
    transceiverInformation: AISTransceiverInformation,
    unitType: AISUnitType,
    hasDisplay: Bool,
    hasDSC: Bool,
    canUseWholeBand: Bool,
    acceptsMessage22: Bool,
    mode: AISMode,
    isCommunicationStateITDMA: Bool,
    latitude: Double? = nil,
    longitude: Double? = nil,
    courseOverGround: Double? = nil,
    speedOverGround: Double? = nil,
    heading: Double? = nil,
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
    self.unitType = unitType
    self.hasDisplay = hasDisplay
    self.hasDSC = hasDSC
    self.canUseWholeBand = canUseWholeBand
    self.acceptsMessage22 = acceptsMessage22
    self.mode = mode
    self.isCommunicationStateITDMA = isCommunicationStateITDMA
    self.sequenceID = sequenceID
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
    courseOverGround = reader.readUInt16(resolution: 1e-04)
    speedOverGround = reader.readUInt16(resolution: 0.01)
    reader.skip(2)  // Communication state.
    transceiverInformation = AISTransceiverInformation(rawValue: (reader.readUInt8() >> 3) & 0x1f)
    heading = reader.readUInt16(resolution: 1e-04)
    _ = reader.readUInt8()  // Regional application.
    let unitFlags = reader.readUInt8()
    unitType = AISUnitType(rawValue: (unitFlags >> 2) & 0x01)
    hasDisplay = unitFlags & 0x08 != 0
    hasDSC = unitFlags & 0x10 != 0
    canUseWholeBand = unitFlags & 0x20 != 0
    acceptsMessage22 = unitFlags & 0x40 != 0
    mode = AISMode(rawValue: (unitFlags >> 7) & 0x01)
    isCommunicationStateITDMA = reader.readUInt8() & 0x01 != 0
    sequenceID = reader.readOptionalUInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(userID)
    writer.appendInt32(longitude, resolution: 1e-07)
    writer.appendInt32(latitude, resolution: 1e-07)
    writer.appendUInt8(
      (timestampSecond & 0x3f) << 2 | (isRAIMInUse ? 0x02 : 0) | (isPositionAccurate ? 0x01 : 0))
    writer.appendUInt16(courseOverGround, resolution: 1e-04)
    writer.appendUInt16(speedOverGround, resolution: 0.01)
    writer.appendUInt8(0xff)  // Communication state (19 bits).
    writer.appendUInt8(0xff)
    writer.appendUInt8((transceiverInformation.rawValue & 0x1f) << 3 | 0x07)
    writer.appendUInt16(heading, resolution: 1e-04)
    writer.appendUInt8(0xff)  // Regional application.
    writer.appendUInt8(
      (mode.rawValue & 0x01) << 7 | (acceptsMessage22 ? 0x40 : 0) | (canUseWholeBand ? 0x20 : 0)
        | (hasDSC ? 0x10 : 0) | (hasDisplay ? 0x08 : 0) | (unitType.rawValue & 0x01) << 2)
    writer.appendUInt8(0xfe | (isCommunicationStateITDMA ? 0x01 : 0))
    writer.appendUInt8(sequenceID)
  }
}
