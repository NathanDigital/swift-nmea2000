// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The state of a man-overboard notification.
///
/// Ports `tN2kMOBStatus`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct MOBStatus: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// MOB emitter activated.
  public static let emitterActivated = Self(rawValue: 0)

  /// Manual on-board MOB button activation.
  public static let manualButtonActivation = Self(rawValue: 1)

  /// Test mode.
  public static let testMode = Self(rawValue: 2)

  /// MOB not active.
  public static let notActive = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .emitterActivated: "MOB emitter activated"
    case .manualButtonActivation: "manual on-board MOB button activation"
    case .testMode: "test mode"
    case .notActive: "MOB not active"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The source of a man-overboard position.
///
/// Ports `tN2kMOBPositionSource`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct MOBPositionSource: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Estimated by vessel.
  public static let estimatedByVessel = Self(rawValue: 0)

  /// Reported by MOB emitter.
  public static let reportedByEmitter = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .estimatedByVessel: "estimated by vessel"
    case .reportedByEmitter: "reported by MOB emitter"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The battery status of a man-overboard emitter.
///
/// Ports `tN2kMOBEmitterBatteryStatus`. Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct MOBEmitterBatteryStatus: RawRepresentable, Hashable, Sendable, CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Good.
  public static let good = Self(rawValue: 0)

  /// Low.
  public static let low = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .good: "good"
    case .low: "low"
    default: "unknown (\(rawValue))"
    }
  }
}
