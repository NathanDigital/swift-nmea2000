// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127507, charger status.
///
/// Ports `SetN2kPGN127507` / `ParseN2kPGN127507`. This port sends the equalization time in minutes
/// rather than upstream's seconds; see ``equalizationTimeRemaining``.
public struct ChargerStatus: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127507
  public static let defaultPriority: UInt8 = 6

  /// The charger instance.
  public var instance: UInt8

  /// The instance of the battery being charged.
  public var batteryInstance: UInt8

  /// The charger operating state.
  public var chargeState: ChargeState

  /// How the charger cooperates with other chargers.
  public var chargerMode: ChargerMode

  /// Whether the charger is enabled.
  public var enabled: OnOffStatus

  /// Whether equalization is pending.
  public var equalizationPending: OnOffStatus

  /// The equalization time remaining, in seconds, sent in whole minutes, or `nil` if not available.
  /// Upstream encodes this field in seconds but decodes it in minutes; canboat defines it in
  /// minutes, so this port uses minutes both ways.
  public var equalizationTimeRemaining: Double?

  /// Creates a charger status message.
  ///
  /// The defaults match upstream's `SetN2kChargerStatus`.
  public init(
    instance: UInt8,
    batteryInstance: UInt8,
    chargeState: ChargeState,
    chargerMode: ChargerMode = .standalone,
    enabled: OnOffStatus = .on,
    equalizationPending: OnOffStatus = .unavailable,
    equalizationTimeRemaining: Double? = nil
  ) {
    self.instance = instance
    self.batteryInstance = batteryInstance
    self.chargeState = chargeState
    self.chargerMode = chargerMode
    self.enabled = enabled
    self.equalizationPending = equalizationPending
    self.equalizationTimeRemaining = equalizationTimeRemaining
  }

  public init(from reader: inout MessageReader) {
    instance = reader.readUInt8()
    batteryInstance = reader.readUInt8()
    let states = reader.readUInt8()
    chargeState = ChargeState(rawValue: states & 0x0f)
    chargerMode = ChargerMode(rawValue: (states >> 4) & 0x0f)
    let flags = reader.readUInt8()
    enabled = OnOffStatus(rawValue: flags & 0x03)
    equalizationPending = OnOffStatus(rawValue: (flags >> 2) & 0x03)
    equalizationTimeRemaining = reader.readUInt16(resolution: 60)
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendUInt8(batteryInstance)
    writer.appendUInt8((chargerMode.rawValue & 0x0f) << 4 | chargeState.rawValue & 0x0f)
    writer.appendUInt8(
      0x0f << 4 | (equalizationPending.rawValue & 0x03) << 2 | enabled.rawValue & 0x03)
    // Deliberate divergence: upstream encodes with a resolution of 1.
    writer.appendUInt16(equalizationTimeRemaining, resolution: 60)
  }
}
