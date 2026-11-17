// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129809, AIS class B static data, part A.
///
/// Ports `SetN2kPGN129809` / `ParseN2kPGN129809`.
public struct AISClassBStaticDataPartA: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129809
  public static let defaultPriority: UInt8 = 6

  /// The AIS message ID. Only the low six bits are sent.
  public var messageID: UInt8

  /// How many times the message has been repeated.
  public var repeatIndicator: AISRepeatIndicator

  /// The MMSI of the reporting station.
  public var userID: UInt32

  /// The vessel name, up to 20 AIS characters.
  public var name: String

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The sequence identifier, or `nil` if not available.
  public var sequenceID: UInt8?

  /// Creates an AIS class B static data, part A message.
  ///
  /// The defaults match upstream's `SetN2kPGN129809`.
  public init(
    messageID: UInt8,
    repeatIndicator: AISRepeatIndicator,
    userID: UInt32,
    name: String,
    transceiverInformation: AISTransceiverInformation = .channelAReception,
    sequenceID: UInt8? = nil
  ) {
    self.messageID = messageID
    self.repeatIndicator = repeatIndicator
    self.userID = userID
    self.name = name
    self.transceiverInformation = transceiverInformation
    self.sequenceID = sequenceID
  }

  public init(from reader: inout MessageReader) {
    let header = reader.readUInt8()
    messageID = header & 0x3f
    repeatIndicator = AISRepeatIndicator(rawValue: (header >> 6) & 0x03)
    userID = reader.readUInt32()
    name = reader.readFixedString(count: 20, terminator: UInt8(ascii: "@")) ?? ""
    transceiverInformation = AISTransceiverInformation(rawValue: reader.readUInt8() & 0x1f)
    sequenceID = reader.readOptionalUInt8()
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(userID)
    writer.appendAISString(name, count: 20)
    writer.appendUInt8(0xe0 | transceiverInformation.rawValue & 0x1f)
    writer.appendUInt8(sequenceID)
  }
}
