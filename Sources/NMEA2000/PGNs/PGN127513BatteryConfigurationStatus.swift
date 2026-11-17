// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127513, battery configuration status.
///
/// Ports `SetN2kPGN127513` / `ParseN2kPGN127513`. This port decodes the capacity as unsigned and a
/// missing Peukert exponent as `nil`; see ``capacity`` and ``peukertExponent``.
public struct BatteryConfigurationStatus: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 127513
  public static let defaultPriority: UInt8 = 6

  /// The battery instance.
  public var batteryInstance: UInt8

  /// The construction of the battery.
  public var type: BatteryType

  /// Whether the battery supports equalization.
  public var supportsEqualization: BatteryEqualizationSupport

  /// The nominal voltage of the battery.
  public var nominalVoltage: BatteryNominalVoltage

  /// The chemistry of the battery.
  public var chemistry: BatteryChemistry

  /// The battery capacity, in coulombs. Upstream decodes this unsigned field as signed; this port
  /// decodes it unsigned, or `nil` if not available.
  public var capacity: Double?

  /// The temperature coefficient, in percent, or `nil` if not available.
  public var temperatureCoefficient: Int8?

  /// The Peukert exponent, or `nil` if not available. Values below 1 or above 1.504 are sent as not available, as upstream sends them. Upstream
  /// decodes "not available" as -999999999; this port decodes it as `nil`.
  public var peukertExponent: Double?

  /// The charge efficiency factor, in percent, or `nil` if not available.
  public var chargeEfficiencyFactor: Int8?

  /// Creates a battery configuration status message.
  public init(
    batteryInstance: UInt8,
    type: BatteryType,
    supportsEqualization: BatteryEqualizationSupport,
    nominalVoltage: BatteryNominalVoltage,
    chemistry: BatteryChemistry,
    capacity: Double?,
    temperatureCoefficient: Int8?,
    peukertExponent: Double?,
    chargeEfficiencyFactor: Int8?
  ) {
    self.batteryInstance = batteryInstance
    self.type = type
    self.supportsEqualization = supportsEqualization
    self.nominalVoltage = nominalVoltage
    self.chemistry = chemistry
    self.capacity = capacity
    self.temperatureCoefficient = temperatureCoefficient
    self.peukertExponent = peukertExponent
    self.chargeEfficiencyFactor = chargeEfficiencyFactor
  }

  public init(from reader: inout MessageReader) {
    batteryInstance = reader.readUInt8()
    let typeAndSupport = reader.readUInt8()
    type = BatteryType(rawValue: typeAndSupport & 0x0f)
    supportsEqualization = BatteryEqualizationSupport(rawValue: (typeAndSupport >> 4) & 0x03)
    let voltageAndChemistry = reader.readUInt8()
    nominalVoltage = BatteryNominalVoltage(rawValue: voltageAndChemistry & 0x0f)
    chemistry = BatteryChemistry(rawValue: (voltageAndChemistry >> 4) & 0x0f)
    // Deliberate divergence: upstream reads this as signed.
    capacity = reader.readUInt16(resolution: 3600)
    temperatureCoefficient = reader.readOptionalInt8()
    peukertExponent = reader.readUInt8(resolution: 0.002).map { $0 + 1 }
    chargeEfficiencyFactor = reader.readOptionalInt8()
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(batteryInstance)
    writer.appendUInt8(0xc0 | (supportsEqualization.rawValue & 0x03) << 4 | type.rawValue & 0x0f)
    writer.appendUInt8((chemistry.rawValue & 0x0f) << 4 | nominalVoltage.rawValue & 0x0f)
    writer.appendUInt16(capacity, resolution: 3600)
    writer.appendInt8(temperatureCoefficient)
    // Sent as the excess over 1. Upstream sends "not available" for anything out of range,
    // comparing against the long double 0.504L. The nearest double to 0.504 is slightly above
    // it, so `< 0.504` here is exactly upstream's `<= 0.504L`.
    if let excess = peukertExponent.map({ $0 - 1 }), excess >= 0, excess < 0.504 {
      writer.appendUInt8(excess, resolution: 0.002)
    } else {
      writer.appendUInt8(0xff)
    }
    writer.appendInt8(chargeEfficiencyFactor)
  }
}
