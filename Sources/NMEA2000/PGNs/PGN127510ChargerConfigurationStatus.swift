// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127510, charger configuration status.
///
/// Ports `SetN2kPGN127510` / `ParseN2kPGN127510`. This port sends the equalization time in minutes
/// and decodes the battery temperature with all four bits; see ``equalizationTime`` and
/// ``batteryTemperature``.
public struct ChargerConfigurationStatus: ParameterGroup {
  public static let pgn: UInt32 = 127510
  public static let defaultPriority: UInt8 = 6

  /// The charger instance.
  public var chargerInstance: UInt8

  /// The instance of the battery being charged.
  public var batteryInstance: UInt8

  /// Whether the charger is enabled.
  public var enabled: OnOffStatus

  /// The charge current limit, in percent (0 to 252), or `nil` if not available.
  public var chargeCurrentLimit: UInt8?

  /// The charging algorithm.
  public var chargingAlgorithm: ChargingAlgorithm

  /// How the charger cooperates with other chargers.
  public var chargerMode: ChargerMode

  /// The battery temperature to assume when no sensor is fitted. Upstream decodes this with the
  /// wrong mask (`& 0x04`); this port decodes all four bits.
  public var batteryTemperature: BatteryTemperatureEstimate

  /// Whether one-time equalization is enabled.
  public var equalizationEnabled: OnOffStatus

  /// Whether overcharge is enabled.
  public var overchargeEnabled: OnOffStatus

  /// The equalization time, in seconds, sent in whole minutes, or `nil` if not available. Upstream
  /// documents this in seconds but sends the number unscaled; canboat defines the field in minutes,
  /// so this port converts.
  public var equalizationTime: Double?

  /// Creates a charger configuration status message.
  ///
  /// The defaults match upstream's `SetN2kChargerConf`.
  public init(
    chargerInstance: UInt8,
    batteryInstance: UInt8,
    enabled: OnOffStatus = .on,
    chargeCurrentLimit: UInt8? = nil,
    chargingAlgorithm: ChargingAlgorithm = .threeStage,
    chargerMode: ChargerMode = .standalone,
    batteryTemperature: BatteryTemperatureEstimate = .unavailable,
    equalizationEnabled: OnOffStatus = .off,
    overchargeEnabled: OnOffStatus = .off,
    equalizationTime: Double? = 0
  ) {
    self.chargerInstance = chargerInstance
    self.batteryInstance = batteryInstance
    self.enabled = enabled
    self.chargeCurrentLimit = chargeCurrentLimit
    self.chargingAlgorithm = chargingAlgorithm
    self.chargerMode = chargerMode
    self.batteryTemperature = batteryTemperature
    self.equalizationEnabled = equalizationEnabled
    self.overchargeEnabled = overchargeEnabled
    self.equalizationTime = equalizationTime
  }

  public init(decoding reader: inout MessageReader) {
    chargerInstance = reader.readUInt8()
    batteryInstance = reader.readUInt8()
    enabled = OnOffStatus(rawValue: reader.readUInt8() & 0x03)
    chargeCurrentLimit = reader.readOptionalUInt8()
    let modes = reader.readUInt8()
    chargingAlgorithm = ChargingAlgorithm(rawValue: modes & 0x0f)
    chargerMode = ChargerMode(rawValue: (modes >> 4) & 0x0f)
    let flags = reader.readUInt8()
    overchargeEnabled = OnOffStatus(rawValue: (flags >> 6) & 0x03)
    equalizationEnabled = OnOffStatus(rawValue: (flags >> 4) & 0x03)
    // Deliberate divergence: upstream masks with 0x04.
    batteryTemperature = BatteryTemperatureEstimate(rawValue: flags & 0x0f)
    equalizationTime = reader.readUInt16(resolution: 60)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(chargerInstance)
    writer.appendUInt8(batteryInstance)
    writer.appendUInt8(enabled.rawValue & 0x03)
    writer.appendUInt8(chargeCurrentLimit)
    writer.appendUInt8((chargerMode.rawValue & 0x0f) << 4 | chargingAlgorithm.rawValue & 0x0f)
    writer.appendUInt8(
      (overchargeEnabled.rawValue & 0x03) << 6 | (equalizationEnabled.rawValue & 0x03) << 4
        | batteryTemperature.rawValue & 0x0f)
    // Deliberate divergence: upstream sends the seconds value unscaled.
    writer.appendUInt16(equalizationTime, resolution: 60)
  }
}
