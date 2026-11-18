// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129794, AIS class A static and voyage related data.
///
/// Ports `SetN2kPGN129794` / `ParseN2kPGN129794`. The text fields are upper-cased and padded with
/// `@` when sent, as AIS requires; decoding stops at the first `@`.
public struct AISClassAStaticData: ParameterGroup {
  public static let pgn: UInt32 = 129794
  public static let defaultPriority: UInt8 = 6

  /// The AIS message ID. Only the low six bits are sent.
  public var messageID: UInt8

  /// How many times the message has been repeated.
  public var repeatIndicator: AISRepeatIndicator

  /// The MMSI of the reporting station.
  public var userID: UInt32

  /// The ship identification number assigned by the IMO.
  public var imoNumber: UInt32

  /// The call sign, up to 7 AIS characters.
  public var callsign: String

  /// The vessel name, up to 20 AIS characters.
  public var name: String

  /// The vessel type code.
  public var vesselType: UInt8

  /// The vessel length, in metres, or `nil` if not available.
  public var length: Double?

  /// The vessel beam, in metres, or `nil` if not available.
  public var beam: Double?

  /// The distance of the position reference point from starboard, in metres, or `nil` if not
  /// available.
  public var positionReferenceStarboard: Double?

  /// The distance of the position reference point from the bow, in metres, or `nil` if not
  /// available.
  public var positionReferenceBow: Double?

  /// The estimated date of arrival, in days since 1970-01-01, or `nil` if not available.
  public var etaDaysSince1970: UInt16?

  /// The estimated time of arrival, in seconds since midnight UTC, or `nil` if not available.
  public var etaSecondsSinceMidnight: Double?

  /// The maximum present static draught, in metres, or `nil` if not available.
  public var draught: Double?

  /// The destination, up to 20 AIS characters.
  public var destination: String

  /// The ITU-R M.1371 version the transponder implements.
  public var aisVersion: AISVersion

  /// The type of electronic position fixing device.
  public var gnssType: GNSSType

  /// Whether the data terminal equipment is ready.
  public var dte: AISDTEStatus

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// Creates an AIS class A static and voyage related data message.
  ///
  /// Defaults that aren't `nil` match upstream's `SetN2kPGN129794`.
  public init(
    messageID: UInt8,
    repeatIndicator: AISRepeatIndicator,
    userID: UInt32,
    imoNumber: UInt32,
    callsign: String,
    name: String,
    vesselType: UInt8,
    destination: String,
    aisVersion: AISVersion,
    gnssType: GNSSType,
    dte: AISDTEStatus,
    length: Double? = nil,
    beam: Double? = nil,
    positionReferenceStarboard: Double? = nil,
    positionReferenceBow: Double? = nil,
    etaDaysSince1970: UInt16? = nil,
    etaSecondsSinceMidnight: Double? = nil,
    draught: Double? = nil,
    transceiverInformation: AISTransceiverInformation = .channelAReception,
    sequenceID: UInt8? = nil
  ) {
    self.messageID = messageID
    self.repeatIndicator = repeatIndicator
    self.userID = userID
    self.imoNumber = imoNumber
    self.callsign = callsign
    self.name = name
    self.vesselType = vesselType
    self.length = length
    self.beam = beam
    self.positionReferenceStarboard = positionReferenceStarboard
    self.positionReferenceBow = positionReferenceBow
    self.etaDaysSince1970 = etaDaysSince1970
    self.etaSecondsSinceMidnight = etaSecondsSinceMidnight
    self.draught = draught
    self.destination = destination
    self.aisVersion = aisVersion
    self.gnssType = gnssType
    self.dte = dte
    self.transceiverInformation = transceiverInformation
    self.sequenceID = sequenceID
  }

  public init(decoding reader: inout MessageReader) {
    let header = reader.readUInt8()
    messageID = header & 0x3f
    repeatIndicator = AISRepeatIndicator(rawValue: (header >> 6) & 0x03)
    userID = reader.readUInt32()
    imoNumber = reader.readUInt32()
    callsign = reader.readFixedString(count: 7, terminator: UInt8(ascii: "@")) ?? ""
    name = reader.readFixedString(count: 20, terminator: UInt8(ascii: "@")) ?? ""
    vesselType = reader.readUInt8()
    length = reader.readUInt16(resolution: 0.1)
    beam = reader.readUInt16(resolution: 0.1)
    positionReferenceStarboard = reader.readUInt16(resolution: 0.1)
    positionReferenceBow = reader.readUInt16(resolution: 0.1)
    etaDaysSince1970 = reader.readOptionalUInt16()
    etaSecondsSinceMidnight = reader.readUInt32(resolution: 0.0001)
    draught = reader.readInt16(resolution: 0.01)
    destination = reader.readFixedString(count: 20, terminator: UInt8(ascii: "@")) ?? ""
    let versions = reader.readUInt8()
    aisVersion = AISVersion(rawValue: versions & 0x03)
    gnssType = GNSSType(rawValue: (versions >> 2) & 0x0f)
    dte = AISDTEStatus(rawValue: (versions >> 6) & 0x01)
    transceiverInformation = AISTransceiverInformation(rawValue: reader.readUInt8() & 0x1f)
    sequenceID = reader.readOptionalUInt8()
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(userID)
    writer.appendUInt32(imoNumber)
    writer.appendAISString(callsign, count: 7)
    writer.appendAISString(name, count: 20)
    writer.appendUInt8(vesselType)
    writer.appendUInt16(length, resolution: 0.1)
    writer.appendUInt16(beam, resolution: 0.1)
    writer.appendUInt16(positionReferenceStarboard, resolution: 0.1)
    writer.appendUInt16(positionReferenceBow, resolution: 0.1)
    writer.appendUInt16(etaDaysSince1970)
    writer.appendUInt32(etaSecondsSinceMidnight, resolution: 0.0001)
    writer.appendInt16(draught, resolution: 0.01)
    writer.appendAISString(destination, count: 20)
    writer.appendUInt8(
      (dte.rawValue & 0x01) << 6 | (gnssType.rawValue & 0x0f) << 2 | aisVersion.rawValue & 0x03)
    writer.appendUInt8(0xe0 | transceiverInformation.rawValue & 0x1f)
    writer.appendUInt8(sequenceID)
  }
}
