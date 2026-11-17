// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127502, switch bank control: commands for up to 28 switches.
///
/// Ports `SetN2kPGN127502` / `ParseN2kPGN127502`. Upstream's
/// `tN2kBinaryStatus` becomes the ``statuses`` array.
public struct SwitchBankControl: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127502
  public static let defaultPriority: UInt8 = 3

  /// The number of switches in one bank.
  public static let statusCount = SwitchBank.statusCount

  /// The instance of the switch bank being controlled.
  public var targetInstance: UInt8

  /// The commanded switch states, in order from switch 1.
  ///
  /// Up to ``statusCount`` are sent; switches not listed are sent as
  /// ``OnOffStatus/unavailable``. Decoding always produces ``statusCount``
  /// states.
  public var statuses: [OnOffStatus]

  /// Creates a switch bank control message.
  public init(targetInstance: UInt8, statuses: [OnOffStatus]) {
    self.targetInstance = targetInstance
    self.statuses = statuses
  }

  public init(from reader: inout MessageReader) {
    (targetInstance, statuses) = SwitchBank.decode(from: &reader)
  }

  public func encode(to writer: inout MessageWriter) {
    SwitchBank.encode(instance: targetInstance, statuses: statuses, to: &writer)
  }
}
