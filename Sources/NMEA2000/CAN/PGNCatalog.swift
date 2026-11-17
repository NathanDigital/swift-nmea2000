// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Which PGNs travel as single frames and which as fast packets.
///
/// A CAN frame doesn't say whether it is a whole message or one frame of a
/// fast packet, so both ends have to know each PGN's framing in advance. The
/// catalog starts with upstream's default lists, which an application can
/// replace or extend:
///
/// ```swift
/// var catalog = PGNCatalog()
/// catalog.fastPacketPGNs.insert(130820)  // like upstream's ExtendFastPacketMessages
/// ```
///
/// Replacing a list is like upstream's `SetSingleFrameMessages` or
/// `SetFastPacketMessages`, which also drop the defaults. The system PGNs,
/// the mandatory fast-packet PGNs and the proprietary fast-packet ranges always
/// apply.
///
/// Ports the PGN classification in upstream's `NMEA2000.cpp`
/// (`IsDefaultSingleFrameMessage`, `IsDefaultFastPacketMessage` and their
/// siblings, `IsFastPacketPGN` and `CheckKnownMessage`).
public struct PGNCatalog: Sendable, Hashable {
  /// The single-frame PGNs upstream knows by default
  /// (`IsDefaultSingleFrameMessage`).
  public static let defaultSingleFramePGNs: Set<UInt32> = [
    126992, 126993, 127245, 127250, 127251, 127252, 127257, 127488, 127493, 127501, 127505,
    127508, 127750, 128259, 128267, 129025, 129026, 129283, 130306, 130310, 130311, 130312,
    130313, 130314, 130316, 130576,
  ]

  /// The fast-packet PGNs upstream knows by default
  /// (`IsDefaultFastPacketMessage`).
  public static let defaultFastPacketPGNs: Set<UInt32> = [
    126983, 126984, 126985, 126986, 126987, 126988, 127233, 127237, 127489, 127490, 127491,
    127494, 127495, 127496, 127497, 127498, 127503, 127504, 127506, 127507, 127509, 127510,
    127511, 127512, 127513, 127514, 128275, 128520, 128538, 129029, 129038, 129039, 129040,
    129041, 129044, 129045, 129284, 129285, 129301, 129302, 129538, 129540, 129541, 129542,
    129545, 129547, 129549, 129551, 129556, 129792, 129793, 129794, 129795, 129796, 129797,
    129798, 129799, 129800, 129801, 129802, 129803, 129804, 129805, 129806, 129807, 129808,
    129809, 129810, 129811, 129812, 129813, 129814, 129815, 129816, 130052, 130053, 130054,
    130060, 130061, 130064, 130065, 130066, 130067, 130068, 130069, 130070, 130071, 130072,
    130073, 130074, 130320, 130321, 130322, 130323, 130324, 130330, 130561, 130562, 130563,
    130564, 130565, 130566, 130567, 130577, 130578, 130568, 130569, 130570, 130571, 130572,
    130573, 130574, 130575, 130580, 130581, 130583, 130584, 130586,
  ]

  /// The fast-packet PGNs every device must support: PGN list, product
  /// information and configuration information
  /// (`IsMandatoryFastPacketMessage`).
  public static let mandatoryFastPacketPGNs: Set<UInt32> = [126464, 126996, 126998]

  /// The single-frame network management PGNs: ISO acknowledgement, ISO
  /// request, transport protocol data transfer and connection management, and
  /// ISO address claim (`IsSingleFrameSystemMessage`).
  public static let singleFrameSystemPGNs: Set<UInt32> = [59392, 59904, 60160, 60416, 60928]

  /// The fast-packet network management PGNs: commanded address and group
  /// function (`IsFastPacketSystemMessage`).
  public static let fastPacketSystemPGNs: Set<UInt32> = [65240, 126208]

  /// The single-frame application PGNs this catalog knows.
  public var singleFramePGNs: Set<UInt32>

  /// The fast-packet application PGNs this catalog knows, in addition to the
  /// mandatory, system and proprietary fast-packet PGNs.
  public var fastPacketPGNs: Set<UInt32>

  /// Creates a catalog.
  ///
  /// - Parameters:
  ///   - singleFramePGNs: The single-frame application PGNs.
  ///   - fastPacketPGNs: The fast-packet application PGNs.
  public init(
    singleFramePGNs: Set<UInt32> = PGNCatalog.defaultSingleFramePGNs,
    fastPacketPGNs: Set<UInt32> = PGNCatalog.defaultFastPacketPGNs
  ) {
    self.singleFramePGNs = singleFramePGNs
    self.fastPacketPGNs = fastPacketPGNs
  }

  /// Whether a PGN is in a proprietary fast-packet range: 126720, or
  /// 130816 through 131071 (`IsProprietaryFastPacketMessage`).
  public static func isProprietaryFastPacket(_ pgn: UInt32) -> Bool {
    pgn == 126720 || (130816...131071).contains(pgn)
  }

  /// Whether a PGN is proprietary: a proprietary fast-packet PGN, 61184, or
  /// 65280 through 65535 (`tNMEA2000::IsProprietaryMessage`).
  public static func isProprietary(_ pgn: UInt32) -> Bool {
    isProprietaryFastPacket(pgn) || pgn == 61184 || (65280...65535).contains(pgn)
  }

  /// Whether to send a PGN as a fast packet (`IsFastPacketPGN`).
  ///
  /// Sending doesn't consult the single-frame list, so a PGN in both lists is
  /// sent as a fast packet, as upstream does. A message longer than eight
  /// bytes is sent as a fast packet whatever its PGN.
  public func isFastPacket(_ pgn: UInt32) -> Bool {
    Self.fastPacketSystemPGNs.contains(pgn) || Self.mandatoryFastPacketPGNs.contains(pgn)
      || fastPacketPGNs.contains(pgn) || Self.isProprietaryFastPacket(pgn)
  }

  /// How a received PGN is framed and handled (`CheckKnownMessage`).
  func classify(_ pgn: UInt32) -> Classification {
    if pgn == 0 {
      return Classification(isKnown: false, isSystem: false, isFastPacket: false)
    }
    // Upstream checks its default lists, then the mandatory and system
    // PGNs, then the application's lists. No default PGN is mandatory or a
    // system PGN, so checking those first keeps upstream's order even though
    // the catalog's sets hold the defaults and the application's PGNs
    // together.
    if Self.mandatoryFastPacketPGNs.contains(pgn) {
      return Classification(isKnown: true, isSystem: false, isFastPacket: true)
    }
    if Self.singleFrameSystemPGNs.contains(pgn) {
      return Classification(isKnown: true, isSystem: true, isFastPacket: false)
    }
    if Self.fastPacketSystemPGNs.contains(pgn) {
      return Classification(isKnown: true, isSystem: true, isFastPacket: true)
    }
    if singleFramePGNs.contains(pgn) {
      return Classification(isKnown: true, isSystem: false, isFastPacket: false)
    }
    if fastPacketPGNs.contains(pgn) {
      return Classification(isKnown: true, isSystem: false, isFastPacket: true)
    }
    return Classification(
      isKnown: false, isSystem: false, isFastPacket: Self.isProprietaryFastPacket(pgn))
  }

  /// How a received PGN is framed and handled.
  struct Classification: Equatable {
    /// Whether the PGN is in one of the catalog's lists.
    var isKnown: Bool
    /// Whether the PGN is a network management PGN the node handles itself.
    var isSystem: Bool
    /// Whether the PGN arrives as a fast packet.
    var isFastPacket: Bool
  }
}
