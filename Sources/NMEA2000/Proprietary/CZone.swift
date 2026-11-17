// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A switch bank status report from a BEP/Mastervolt CZone device, such as
/// a Contact 6 Plus, on PGN 65284 (single frame) or 65301 (fast packet).
///
/// Upstream only decodes these, from observed traffic, so this type has no
/// encoder.
///
/// Ports `ParseN2kPGN65284CZoneSwitchStatus`,
/// `ParseN2kPGN65301CZoneSwitchStatus`, `N2kCZoneIsSwitchOn` and
/// `N2kCZoneSwitchMask`.
public struct CZoneSwitchStatus: Sendable, Codable, Hashable {
  /// The single-frame switch status PGN.
  public static let singleFramePGN: UInt32 = 65284

  /// The fast-packet switch status PGN.
  public static let fastPacketPGN: UInt32 = 65301

  /// The number of switches in a bank.
  public static let switchCount = 6

  /// The field identifier of a switch summary record.
  public static let switchSummaryField: UInt8 = 0x1e

  /// CZone's proprietary header.
  static let header: UInt16 = 0x9927

  /// The bank instance, which matches the device instance in the device's
  /// product information.
  public var bankInstance: UInt8

  /// What the record holds; ``switchSummaryField`` for the switch states.
  public var fieldIdentifier: UInt8

  /// The switch states, one bit each from switch 1 in bit 0, 1 for on.
  public var switchBits: UInt8

  /// The up to three bytes after the switch states, 0 where absent.
  public var reserved: [UInt8]

  /// The first eight bytes of the payload, for working out what else the
  /// message holds.
  public var rawData: [UInt8]

  /// Decodes a switch status message.
  ///
  /// - Throws: ``MessageDecodingError/unexpectedPGN(expected:actual:)`` for
  ///   another PGN, or ``MessageDecodingError/invalidPayload(pgn:reason:)``
  ///   for a payload shorter than five bytes or without CZone's header, or a
  ///   fast-packet message that isn't a switch summary.
  public init(_ message: Message) throws(MessageDecodingError) {
    guard message.pgn == Self.singleFramePGN || message.pgn == Self.fastPacketPGN else {
      throw .unexpectedPGN(expected: Self.singleFramePGN, actual: message.pgn)
    }
    var reader = MessageReader(message)
    guard message.data.count >= 5, reader.readUInt16() == Self.header else {
      throw .invalidPayload(pgn: message.pgn, reason: "not a CZone switch status")
    }
    rawData = Array(message.data.prefix(8))
    bankInstance = reader.readUInt8()
    fieldIdentifier = reader.readUInt8()
    switchBits = reader.readUInt8()
    reserved = (0..<3).map { _ in reader.remainingCount > 0 ? reader.readUInt8() : 0 }
    guard message.pgn == Self.singleFramePGN || isSwitchSummary else {
      throw .invalidPayload(pgn: message.pgn, reason: "not a switch summary")
    }
  }

  /// Whether the record holds the switch states.
  public var isSwitchSummary: Bool { fieldIdentifier == Self.switchSummaryField }

  /// The switch states of the six switches (`N2kCZoneSwitchMask`).
  public var switchMask: UInt8 { switchBits & (1 << Self.switchCount - 1) }

  /// Whether a switch, numbered from 1 to 6, is on. `false` when the record
  /// isn't a switch summary (`N2kCZoneIsSwitchOn`).
  public func isSwitchOn(_ number: Int) -> Bool {
    guard isSwitchSummary, (1...Self.switchCount).contains(number) else { return false }
    return switchBits >> (number - 1) & 1 != 0
  }
}
