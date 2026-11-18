// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The motion of a windlass.
///
/// Ports `tN2kDD480` (`tN2kWindlassMotionStates`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct WindlassMotionState: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Stopped.
  public static let stopped = Self(rawValue: 0)

  /// Deploying.
  public static let deploying = Self(rawValue: 1)

  /// Retrieving.
  public static let retrieving = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .stopped: "stopped"
    case .deploying: "deploying"
    case .retrieving: "retrieving"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The kind of rode a windlass detects.
///
/// Ports `tN2kDD481` (`tN2kRodeTypeStates`). Values without a name here are kept in ``rawValue``,
/// so they decode and re-encode unchanged.
public struct RodeType: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Chain.
  public static let chain = Self(rawValue: 0)

  /// Rope.
  public static let rope = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .chain: "chain"
    case .rope: "rope"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Whether an anchor is docked.
///
/// Ports `tN2kDD482` (`tN2kAnchorDockingStates`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct AnchorDockingState: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Not docked.
  public static let notDocked = Self(rawValue: 0)

  /// Fully docked.
  public static let fullyDocked = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .notDocked: "not docked"
    case .fullyDocked: "fully docked"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// A windlass direction command.
///
/// Ports `tN2kDD484` (`tN2kWindlassDirectionControl`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct WindlassDirectionControl: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Off.
  public static let off = Self(rawValue: 0)

  /// Down.
  public static let down = Self(rawValue: 1)

  /// Up.
  public static let up = Self(rawValue: 2)

  public var description: String {
    switch self {
    case .off: "off"
    case .down: "down"
    case .up: "up"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Windlass monitoring event flags.
///
/// Ports `tN2kDD477` (`tN2kWindlassMonitoringEvents`).
public struct WindlassMonitoringEvents: OptionSet, Codable, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt8

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Controller under-voltage cutout.
  public static let controllerUnderVoltageCutout = Self(rawValue: 1 << 0)

  /// Controller over-current cutout.
  public static let controllerOverCurrentCutout = Self(rawValue: 1 << 1)

  /// Controller over-temperature cutout.
  public static let controllerOverTemperatureCutout = Self(rawValue: 1 << 2)
}

/// Windlass control event flags.
///
/// Ports `tN2kDD478` (`tN2kWindlassControlEvents`).
public struct WindlassControlEvents: OptionSet, Codable, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt8

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Another device is controlling the windlass.
  public static let anotherDeviceControllingWindlass = Self(rawValue: 1 << 0)
}

/// Windlass operating event flags.
///
/// Ports `tN2kDD483` (`tN2kWindlassOperatingEvents`).
public struct WindlassOperatingEvents: OptionSet, Codable, Hashable, Sendable {
  /// The flags as they appear on the wire.
  public var rawValue: UInt8

  /// Creates a set of flags from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// System error.
  public static let systemError = Self(rawValue: 1 << 0)

  /// Sensor error.
  public static let sensorError = Self(rawValue: 1 << 1)

  /// No windlass motion detected.
  public static let noWindlassMotionDetected = Self(rawValue: 1 << 2)

  /// Retrieval docking distance reached.
  public static let retrievalDockingDistanceReached = Self(rawValue: 1 << 3)

  /// End of rode reached.
  public static let endOfRodeReached = Self(rawValue: 1 << 4)
}

extension WindlassMonitoringEvents: CustomStringConvertible {
  /// The flags that are set, by name, with any unnamed bits as a raw value.
  public var description: String {
    flagDescription(
      rawValue,
      [
        (Self.controllerUnderVoltageCutout.rawValue, "controller under-voltage cutout"),
        (Self.controllerOverCurrentCutout.rawValue, "controller over-current cutout"),
        (Self.controllerOverTemperatureCutout.rawValue, "controller over-temperature cutout"),
      ])
  }
}

extension WindlassControlEvents: CustomStringConvertible {
  /// The flags that are set, by name, with any unnamed bits as a raw value.
  public var description: String {
    flagDescription(
      rawValue,
      [
        (
          Self.anotherDeviceControllingWindlass.rawValue,
          "another device is controlling the windlass"
        )
      ])
  }
}

extension WindlassOperatingEvents: CustomStringConvertible {
  /// The flags that are set, by name, with any unnamed bits as a raw value.
  public var description: String {
    flagDescription(
      rawValue,
      [
        (Self.systemError.rawValue, "system error"),
        (Self.sensorError.rawValue, "sensor error"),
        (Self.noWindlassMotionDetected.rawValue, "no windlass motion detected"),
        (Self.retrievalDockingDistanceReached.rawValue, "retrieval docking distance reached"),
        (Self.endOfRodeReached.rawValue, "end of rode reached"),
      ])
  }
}
