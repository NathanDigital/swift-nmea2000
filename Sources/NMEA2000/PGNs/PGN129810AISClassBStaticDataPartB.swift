// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129810, AIS class B static data, part B.
///
/// Ports `SetN2kPGN129810` / `ParseN2kPGN129810`.
public struct AISClassBStaticDataPartB: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129810
  public static let defaultPriority: UInt8 = 6

  /// The AIS message ID. Only the low six bits are sent.
  public var messageID: UInt8

  /// How many times the message has been repeated.
  public var repeatIndicator: AISRepeatIndicator

  /// The MMSI of the reporting station.
  public var userID: UInt32

  /// The vessel type code.
  public var vesselType: UInt8

  /// The vendor identifier, up to 7 AIS characters.
  public var vendor: String

  /// The call sign, up to 7 AIS characters.
  public var callsign: String

  /// The vessel length, in meters, or `nil` if not available.
  public var length: Double?

  /// The vessel beam, in meters, or `nil` if not available.
  public var beam: Double?

  /// The distance of the position reference point from starboard, in meters, or `nil` if not
  /// available.
  public var positionReferenceStarboard: Double?

  /// The distance of the position reference point from the bow, in meters, or `nil` if not
  /// available.
  public var positionReferenceBow: Double?

  /// The MMSI of the mothership.
  public var mothershipID: UInt32

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// Creates an AIS class B static data, part B message.
  ///
  /// The defaults match upstream's `SetN2kPGN129810`. Its `SetN2kAISClassBStaticPartB` alias
  /// defaults the transceiver information to channel A instead.
  public init(
    messageID: UInt8,
    repeatIndicator: AISRepeatIndicator,
    userID: UInt32,
    vesselType: UInt8,
    vendor: String,
    callsign: String,
    length: Double?,
    beam: Double?,
    positionReferenceStarboard: Double?,
    positionReferenceBow: Double?,
    mothershipID: UInt32,
    transceiverInformation: AISTransceiverInformation = .channelBReception,
    sequenceID: UInt8? = nil
  ) {
    self.messageID = messageID
    self.repeatIndicator = repeatIndicator
    self.userID = userID
    self.vesselType = vesselType
    self.vendor = vendor
    self.callsign = callsign
    self.length = length
    self.beam = beam
    self.positionReferenceStarboard = positionReferenceStarboard
    self.positionReferenceBow = positionReferenceBow
    self.mothershipID = mothershipID
    self.transceiverInformation = transceiverInformation
    self.sequenceID = sequenceID
  }

  public init(from reader: inout MessageReader) {
    let header = reader.readUInt8()
    messageID = header & 0x3f
    repeatIndicator = AISRepeatIndicator(rawValue: (header >> 6) & 0x03)
    userID = reader.readUInt32()
    vesselType = reader.readUInt8()
    vendor = reader.readFixedString(count: 7, terminator: UInt8(ascii: "@")) ?? ""
    callsign = reader.readFixedString(count: 7, terminator: UInt8(ascii: "@")) ?? ""
    length = reader.readUInt16(resolution: 0.1)
    beam = reader.readUInt16(resolution: 0.1)
    positionReferenceStarboard = reader.readUInt16(resolution: 0.1)
    positionReferenceBow = reader.readUInt16(resolution: 0.1)
    mothershipID = reader.readUInt32()
    _ = reader.readUInt8()  // Reserved and AIS spare bits.
    transceiverInformation = AISTransceiverInformation(rawValue: reader.readUInt8() & 0x1f)
    sequenceID = reader.readOptionalUInt8()
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(userID)
    writer.appendUInt8(vesselType)
    writer.appendAISString(vendor, count: 7)
    writer.appendAISString(callsign, count: 7)
    writer.appendUInt16(length, resolution: 0.1)
    writer.appendUInt16(beam, resolution: 0.1)
    writer.appendUInt16(positionReferenceStarboard, resolution: 0.1)
    writer.appendUInt16(positionReferenceBow, resolution: 0.1)
    writer.appendUInt32(mothershipID)
    writer.appendUInt8(0x03)  // Reserved and AIS spare bits.
    writer.appendUInt8(0xe0 | transceiverInformation.rawValue & 0x1f)
    writer.appendUInt8(sequenceID)
  }
}
