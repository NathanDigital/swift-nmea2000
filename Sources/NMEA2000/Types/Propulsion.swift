// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A thruster direction command or state.
///
/// Ports `tN2kDD473` (`tN2kThrusterDirectionControl`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct ThrusterDirectionControl: RawRepresentable, Hashable, Sendable,
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

  /// Ready.
  public static let ready = Self(rawValue: 1)

  /// To port.
  public static let toPort = Self(rawValue: 2)

  /// To starboard.
  public static let toStarboard = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .off: "off"
    case .ready: "ready"
    case .toPort: "to port"
    case .toStarboard: "to starboard"
    default: "unknown (\(rawValue))"
    }
  }
}

/// A thruster retraction command or state.
///
/// Ports `tN2kDD474` (`tN2kThrusterRetraction`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct ThrusterRetraction: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Off.
  public static let off = Self(rawValue: 0)

  /// Extend.
  public static let extend = Self(rawValue: 1)

  /// Retract.
  public static let retract = Self(rawValue: 2)

  public var description: String {
    switch self {
    case .off: "off"
    case .extend: "extend"
    case .retract: "retract"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The power supply of a motor.
///
/// Ports `tN2kDD487` (`tN2kMotorPowerType`). Values without a name here are kept in ``rawValue``,
/// so they decode and re-encode unchanged.
public struct MotorPowerType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// 12 V DC.
  public static let dc12V = Self(rawValue: 0)

  /// 24 V DC.
  public static let dc24V = Self(rawValue: 1)

  /// 48 V DC.
  public static let dc48V = Self(rawValue: 2)

  /// 24 V AC.
  public static let ac24V = Self(rawValue: 3)

  /// Hydraulic.
  public static let hydraulic = Self(rawValue: 4)

  public var description: String {
    switch self {
    case .dc12V: "12 V DC"
    case .dc24V: "24 V DC"
    case .dc48V: "48 V DC"
    case .ac24V: "24 V AC"
    case .hydraulic: "hydraulic"
    default: "unknown (\(rawValue))"
    }
  }
}

/// How the speed of a motor is controlled.
///
/// Ports `tN2kDD488` (`tN2kSpeedType`). Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct MotorSpeedType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Single speed.
  public static let singleSpeed = Self(rawValue: 0)

  /// Dual speed.
  public static let dualSpeed = Self(rawValue: 1)

  /// Proportional speed.
  public static let proportionalSpeed = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .singleSpeed: "single speed"
    case .dualSpeed: "dual speed"
    case .proportionalSpeed: "proportional speed"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The gear a transmission is in.
///
/// Ports `tN2kTransmissionGear`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct TransmissionGear: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Forward.
  public static let forward = Self(rawValue: 0)

  /// Neutral.
  public static let neutral = Self(rawValue: 1)

  /// Reverse.
  public static let reverse = Self(rawValue: 2)

  /// Unknown.
  public static let unknown = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .forward: "forward"
    case .neutral: "neutral"
    case .reverse: "reverse"
    case .unknown: "unknown"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Engine warning flags, first set.
///
/// Ports `tN2kDD206` (`tN2kEngineDiscreteStatus1`).
public struct EngineDiscreteStatus1: OptionSet, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt16

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  /// Check engine.
  public static let checkEngine = Self(rawValue: 1 << 0)

  /// Over temperature.
  public static let overTemperature = Self(rawValue: 1 << 1)

  /// Low oil pressure.
  public static let lowOilPressure = Self(rawValue: 1 << 2)

  /// Low oil level.
  public static let lowOilLevel = Self(rawValue: 1 << 3)

  /// Low fuel pressure.
  public static let lowFuelPressure = Self(rawValue: 1 << 4)

  /// Low system voltage.
  public static let lowSystemVoltage = Self(rawValue: 1 << 5)

  /// Low coolant level.
  public static let lowCoolantLevel = Self(rawValue: 1 << 6)

  /// Water flow.
  public static let waterFlow = Self(rawValue: 1 << 7)

  /// Water in fuel.
  public static let waterInFuel = Self(rawValue: 1 << 8)

  /// Charge indicator.
  public static let chargeIndicator = Self(rawValue: 1 << 9)

  /// Preheat indicator.
  public static let preheatIndicator = Self(rawValue: 1 << 10)

  /// High boost pressure.
  public static let highBoostPressure = Self(rawValue: 1 << 11)

  /// Rev limit exceeded.
  public static let revLimitExceeded = Self(rawValue: 1 << 12)

  /// EGR system.
  public static let egrSystem = Self(rawValue: 1 << 13)

  /// Throttle position sensor.
  public static let throttlePositionSensor = Self(rawValue: 1 << 14)

  /// Engine emergency stop mode.
  public static let emergencyStopMode = Self(rawValue: 1 << 15)
}

/// Engine warning flags, second set.
///
/// Ports `tN2kDD223` (`tN2kEngineDiscreteStatus2`).
///
/// Upstream's assignment operator for this type keeps only the low eight bits, dropping the
/// manufacturer flags. PGN 127489 decodes through it, so its port must mask the same way.
public struct EngineDiscreteStatus2: OptionSet, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt16

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt16) {
    self.rawValue = rawValue
  }

  /// Warning level 1.
  public static let warningLevel1 = Self(rawValue: 1 << 0)

  /// Warning level 2.
  public static let warningLevel2 = Self(rawValue: 1 << 1)

  /// Low oil power reduction.
  public static let lowOilPowerReduction = Self(rawValue: 1 << 2)

  /// Maintenance needed.
  public static let maintenanceNeeded = Self(rawValue: 1 << 3)

  /// Engine communication error.
  public static let engineCommunicationError = Self(rawValue: 1 << 4)

  /// Sub or secondary throttle.
  public static let subOrSecondaryThrottle = Self(rawValue: 1 << 5)

  /// Neutral start protect.
  public static let neutralStartProtect = Self(rawValue: 1 << 6)

  /// Engine shutting down.
  public static let engineShuttingDown = Self(rawValue: 1 << 7)

  /// Manufacturer defined 1.
  public static let manufacturer1 = Self(rawValue: 1 << 8)

  /// Manufacturer defined 2.
  public static let manufacturer2 = Self(rawValue: 1 << 9)

  /// Manufacturer defined 3.
  public static let manufacturer3 = Self(rawValue: 1 << 10)

  /// Manufacturer defined 4.
  public static let manufacturer4 = Self(rawValue: 1 << 11)

  /// Manufacturer defined 5.
  public static let manufacturer5 = Self(rawValue: 1 << 12)

  /// Manufacturer defined 6.
  public static let manufacturer6 = Self(rawValue: 1 << 13)

  /// Manufacturer defined 7.
  public static let manufacturer7 = Self(rawValue: 1 << 14)

  /// Manufacturer defined 8.
  public static let manufacturer8 = Self(rawValue: 1 << 15)
}

/// Thruster motor event flags.
///
/// Ports `tN2kDD471` (`tN2kThrusterMotorEvents`).
///
/// Bit 6 is reserved. Upstream's `SetEvents` clears it, and PGN ports that use `SetEvents` must do
/// the same.
public struct ThrusterMotorEvents: OptionSet, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt8

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Motor over-temperature cutout.
  public static let motorOverTemperatureCutout = Self(rawValue: 1 << 0)

  /// Motor over-current cutout.
  public static let motorOverCurrentCutout = Self(rawValue: 1 << 1)

  /// Low oil level warning.
  public static let lowOilLevelWarning = Self(rawValue: 1 << 2)

  /// Oil over-temperature warning.
  public static let oilOverTemperatureWarning = Self(rawValue: 1 << 3)

  /// Controller under-voltage cutout.
  public static let controllerUnderVoltageCutout = Self(rawValue: 1 << 4)

  /// Manufacturer defined.
  public static let manufacturerDefined = Self(rawValue: 1 << 5)

  /// Data not available.
  public static let dataNotAvailable = Self(rawValue: 1 << 7)
}

/// Thruster control event flags.
///
/// Ports `tN2kDD475` (`tN2kThrusterControlEvents`).
public struct ThrusterControlEvents: OptionSet, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt8

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Another device is controlling the thruster.
  public static let anotherDeviceControllingThruster = Self(rawValue: 1 << 0)

  /// Boat speed is too fast.
  public static let boatSpeedTooFast = Self(rawValue: 1 << 1)
}
