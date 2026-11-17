// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127501, binary switch bank status: the state of up to 28 switches.
///
/// Ports both `SetN2kPGN127501` overloads and both `ParseN2kPGN127501`
/// overloads. Upstream's `tN2kBinaryStatus` and its helpers
/// (`N2kGetStatusOnBinaryStatus`, `N2kSetStatusBinaryOnStatus`) become the
/// ``statuses`` array.
public struct BinarySwitchBankStatus: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127501
  public static let defaultPriority: UInt8 = 3

  /// The number of switches in one bank.
  public static let statusCount = SwitchBank.statusCount

  /// The instance of the switch bank.
  public var instance: UInt8

  /// The switch states, in order from switch 1.
  ///
  /// Up to ``statusCount`` are sent; switches not listed are sent as
  /// ``OnOffStatus/unavailable``. Decoding always produces ``statusCount``
  /// states.
  public var statuses: [OnOffStatus]

  /// Creates a binary switch bank status message.
  public init(instance: UInt8, statuses: [OnOffStatus]) {
    self.instance = instance
    self.statuses = statuses
  }

  public init(from reader: inout MessageReader) {
    (instance, statuses) = SwitchBank.decode(from: &reader)
  }

  public func encode(to writer: inout MessageWriter) {
    SwitchBank.encode(instance: instance, statuses: statuses, to: &writer)
  }
}
