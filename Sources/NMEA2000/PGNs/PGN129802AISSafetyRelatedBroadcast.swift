// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129802, AIS safety related broadcast message.
///
/// Ports `SetN2kPGN129802` / `ParseN2kPGN129802`.
public struct AISSafetyRelatedBroadcast: ParameterGroup {
  public static let pgn: UInt32 = 129802
  public static let defaultPriority: UInt8 = 5

  /// The longest text upstream sends, in characters.
  public static let maxTextLength = 163

  /// The AIS message ID. Only the low six bits are sent.
  public var messageID: UInt8

  /// How many times the message has been repeated.
  public var repeatIndicator: AISRepeatIndicator

  /// The MMSI of the source station. Only the low 30 bits are sent.
  public var sourceID: UInt32

  /// The AIS channel and direction the message used.
  public var transceiverInformation: AISTransceiverInformation

  /// The safety related text. Up to ``maxTextLength`` characters are sent, with non-ASCII
  /// characters replaced by `?`.
  public var text: String

  /// Creates an AIS safety related broadcast message message.
  public init(
    messageID: UInt8,
    repeatIndicator: AISRepeatIndicator,
    sourceID: UInt32,
    transceiverInformation: AISTransceiverInformation,
    text: String
  ) {
    self.messageID = messageID
    self.repeatIndicator = repeatIndicator
    self.sourceID = sourceID
    self.transceiverInformation = transceiverInformation
    self.text = text
  }

  public init(decoding reader: inout MessageReader) {
    let header = reader.readUInt8()
    messageID = header & 0x3f
    repeatIndicator = AISRepeatIndicator(rawValue: (header >> 6) & 0x03)
    sourceID = reader.readUInt32() & 0x3fff_ffff
    transceiverInformation = AISTransceiverInformation(rawValue: (reader.readUInt8() >> 1) & 0x1f)
    text = reader.readVariableString() ?? ""
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8((repeatIndicator.rawValue & 0x03) << 6 | messageID & 0x3f)
    writer.appendUInt32(sourceID & 0x3fff_ffff)
    writer.appendUInt8((transceiverInformation.rawValue & 0x1f) << 1 | 0x01)
    writer.appendVariableString(text, maxLength: Self.maxTextLength, encoding: .asciiOnly)
    writer.appendUInt8(0xff)  // Sequence identifier, which upstream always leaves unset.
  }
}
