// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The kind of DC source.
///
/// Ports `tN2kDCType`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct DCSourceType: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Battery.
  public static let battery = Self(rawValue: 0)

  /// Alternator.
  public static let alternator = Self(rawValue: 1)

  /// Converter.
  public static let converter = Self(rawValue: 2)

  /// Solar cell.
  public static let solarCell = Self(rawValue: 3)

  /// Wind generator.
  public static let windGenerator = Self(rawValue: 4)

  public var description: String {
    switch self {
    case .battery: "battery"
    case .alternator: "alternator"
    case .converter: "converter"
    case .solarCell: "solar cell"
    case .windGenerator: "wind generator"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The construction of a battery.
///
/// Ports `tN2kBatType`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct BatteryType: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Flooded.
  public static let flooded = Self(rawValue: 0)

  /// Gel.
  public static let gel = Self(rawValue: 1)

  /// AGM.
  public static let agm = Self(rawValue: 2)

  public var description: String {
    switch self {
    case .flooded: "flooded"
    case .gel: "gel"
    case .agm: "AGM"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Whether a battery supports equalization.
///
/// Ports `tN2kBatEqSupport`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct BatteryEqualizationSupport: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// No.
  public static let no = Self(rawValue: 0)

  /// Yes.
  public static let yes = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .no: "no"
    case .yes: "yes"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The chemistry of a battery.
///
/// Ports `tN2kBatChem`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct BatteryChemistry: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Lead acid.
  public static let leadAcid = Self(rawValue: 0)

  /// Lithium ion.
  public static let lithiumIon = Self(rawValue: 1)

  /// Nickel cadmium.
  public static let nickelCadmium = Self(rawValue: 2)

  /// Zinc oxide.
  public static let zincOxide = Self(rawValue: 3)

  /// Nickel metal hydride.
  public static let nickelMetalHydride = Self(rawValue: 4)

  public var description: String {
    switch self {
    case .leadAcid: "lead acid"
    case .lithiumIon: "lithium ion"
    case .nickelCadmium: "nickel cadmium"
    case .zincOxide: "zinc oxide"
    case .nickelMetalHydride: "nickel metal hydride"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The nominal voltage of a battery.
///
/// Ports `tN2kBatNomVolt`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct BatteryNominalVoltage: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// 6 V.
  public static let volts6 = Self(rawValue: 0)

  /// 12 V.
  public static let volts12 = Self(rawValue: 1)

  /// 24 V.
  public static let volts24 = Self(rawValue: 2)

  /// 32 V.
  public static let volts32 = Self(rawValue: 3)

  /// 36 V.
  ///
  /// Upstream names this value `N2kDCbnv_62v`. Canboat and Maretron's DCM100 manual both define
  /// code 4 as 36 V, and 62 V isn't a nominal battery voltage.
  public static let volts36 = Self(rawValue: 4)

  /// 42 V.
  public static let volts42 = Self(rawValue: 5)

  /// 48 V.
  public static let volts48 = Self(rawValue: 6)

  public var description: String {
    switch self {
    case .volts6: "6 V"
    case .volts12: "12 V"
    case .volts24: "24 V"
    case .volts32: "32 V"
    case .volts36: "36 V"
    case .volts42: "42 V"
    case .volts48: "48 V"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The operating state of a battery charger.
///
/// Ports `tN2kChargeState`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct ChargeState: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Not charging.
  public static let notCharging = Self(rawValue: 0)

  /// Bulk.
  public static let bulk = Self(rawValue: 1)

  /// Absorption.
  public static let absorption = Self(rawValue: 2)

  /// Overcharge.
  public static let overcharge = Self(rawValue: 3)

  /// Equalize.
  public static let equalize = Self(rawValue: 4)

  /// Float.
  public static let float = Self(rawValue: 5)

  /// No float.
  public static let noFloat = Self(rawValue: 6)

  /// Constant VI.
  public static let constantVI = Self(rawValue: 7)

  /// Disabled.
  public static let disabled = Self(rawValue: 8)

  /// Fault.
  public static let fault = Self(rawValue: 9)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .notCharging: "not charging"
    case .bulk: "bulk"
    case .absorption: "absorption"
    case .overcharge: "overcharge"
    case .equalize: "equalize"
    case .float: "float"
    case .noFloat: "no float"
    case .constantVI: "constant VI"
    case .disabled: "disabled"
    case .fault: "fault"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// How a charger cooperates with other chargers.
///
/// Ports `tN2kChargerMode`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct ChargerMode: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Standalone.
  public static let standalone = Self(rawValue: 0)

  /// Primary.
  public static let primary = Self(rawValue: 1)

  /// Secondary.
  public static let secondary = Self(rawValue: 2)

  /// Echo.
  public static let echo = Self(rawValue: 3)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .standalone: "standalone"
    case .primary: "primary"
    case .secondary: "secondary"
    case .echo: "echo"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The operating state of a charger or inverter.
///
/// Ports `tN2kConvMode`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct ConverterOperatingState: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Off.
  public static let off = Self(rawValue: 0)

  /// Low power.
  public static let lowPower = Self(rawValue: 1)

  /// Fault.
  public static let fault = Self(rawValue: 2)

  /// Bulk.
  public static let bulk = Self(rawValue: 3)

  /// Absorption.
  public static let absorption = Self(rawValue: 4)

  /// Float.
  public static let float = Self(rawValue: 5)

  /// Storage.
  public static let storage = Self(rawValue: 6)

  /// Equalize.
  public static let equalize = Self(rawValue: 7)

  /// Passthrough.
  public static let passthrough = Self(rawValue: 8)

  /// Inverting.
  public static let inverting = Self(rawValue: 9)

  /// Assisting.
  public static let assisting = Self(rawValue: 10)

  /// Power supply.
  public static let powerSupply = Self(rawValue: 11)

  /// Hub-1.
  public static let hub1 = Self(rawValue: 252)

  /// Not available.
  public static let unavailable = Self(rawValue: 255)

  public var description: String {
    switch self {
    case .off: "off"
    case .lowPower: "low power"
    case .fault: "fault"
    case .bulk: "bulk"
    case .absorption: "absorption"
    case .float: "float"
    case .storage: "storage"
    case .equalize: "equalize"
    case .passthrough: "passthrough"
    case .inverting: "inverting"
    case .assisting: "assisting"
    case .powerSupply: "power supply"
    case .hub1: "hub-1"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The DC ripple level of a charger or inverter.
///
/// Ports `tN2kRippleState`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct RippleState: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// OK.
  public static let ok = Self(rawValue: 0)

  /// Warning.
  public static let warning = Self(rawValue: 1)

  /// High.
  public static let high = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .ok: "OK"
    case .warning: "warning"
    case .high: "high"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The DC voltage level of a charger or inverter.
///
/// Ports `tN2kDCVolgateState`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct DCVoltageState: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// OK.
  public static let ok = Self(rawValue: 0)

  /// Warning.
  public static let warning = Self(rawValue: 1)

  /// Low.
  ///
  /// Upstream defines `N2kDCVS_Low` as 3, the same value as not available. Canboat and upstream's
  /// sibling enums use 2 for this state, so this port sends 2.
  public static let low = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .ok: "OK"
    case .warning: "warning"
    case .low: "low"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The load level of a charger or inverter.
///
/// Ports `tN2kOverloadState`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct OverloadState: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// OK.
  public static let ok = Self(rawValue: 0)

  /// Warning.
  public static let warning = Self(rawValue: 1)

  /// Overload.
  public static let overload = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .ok: "OK"
    case .warning: "warning"
    case .overload: "overload"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The temperature level of a charger or inverter.
///
/// Ports `tN2kTemperatureState`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct TemperatureState: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// OK.
  public static let ok = Self(rawValue: 0)

  /// Warning.
  public static let warning = Self(rawValue: 1)

  /// High.
  ///
  /// Upstream defines `N2kTS_High` as 3, the same value as not available. Canboat and upstream's
  /// sibling enums use 2 for this state, so this port sends 2.
  public static let high = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .ok: "OK"
    case .warning: "warning"
    case .high: "high"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The algorithm a charger uses.
///
/// Ports `tN2kChargingAlgorithm`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct ChargingAlgorithm: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Trickle.
  public static let trickle = Self(rawValue: 0)

  /// Constant voltage, constant current.
  public static let constantVoltageConstantCurrent = Self(rawValue: 1)

  /// Two stage.
  public static let twoStage = Self(rawValue: 2)

  /// Three stage.
  public static let threeStage = Self(rawValue: 3)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .trickle: "trickle"
    case .constantVoltageConstantCurrent: "constant voltage, constant current"
    case .twoStage: "two stage"
    case .threeStage: "three stage"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The assumed battery temperature when no sensor is fitted.
///
/// Ports `tBattTempNoSensor`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct BatteryTemperatureEstimate: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Cold.
  public static let cold = Self(rawValue: 0)

  /// Warm.
  public static let warm = Self(rawValue: 1)

  /// Hot.
  public static let hot = Self(rawValue: 2)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .cold: "cold"
    case .warm: "warm"
    case .hot: "hot"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}
