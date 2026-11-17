// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A commanded rudder direction.
///
/// Ports `tN2kRudderDirectionOrder`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct RudderDirectionOrder: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// No direction order.
  public static let noDirectionOrder = Self(rawValue: 0)

  /// Move to starboard.
  public static let moveToStarboard = Self(rawValue: 1)

  /// Move to port.
  public static let moveToPort = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 7)

  public var description: String {
    switch self {
    case .noDirectionOrder: "no direction order"
    case .moveToStarboard: "move to starboard"
    case .moveToPort: "move to port"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The steering mode of a heading or track control system.
///
/// Ports `tN2kSteeringMode`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct SteeringMode: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Main steering.
  public static let mainSteering = Self(rawValue: 0)

  /// Non-follow-up device.
  public static let nonFollowUpDevice = Self(rawValue: 1)

  /// Follow-up device.
  public static let followUpDevice = Self(rawValue: 2)

  /// Standalone heading control.
  public static let headingControlStandalone = Self(rawValue: 3)

  /// Heading control.
  public static let headingControl = Self(rawValue: 4)

  /// Track control.
  public static let trackControl = Self(rawValue: 5)

  /// Not available.
  public static let unavailable = Self(rawValue: 7)

  public var description: String {
    switch self {
    case .mainSteering: "main steering"
    case .nonFollowUpDevice: "non-follow-up device"
    case .followUpDevice: "follow-up device"
    case .headingControlStandalone: "standalone heading control"
    case .headingControl: "heading control"
    case .trackControl: "track control"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// How a heading or track control system limits a turn.
///
/// Ports `tN2kTurnMode`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct TurnMode: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Rudder limit controlled.
  public static let rudderLimitControlled = Self(rawValue: 0)

  /// Turn rate controlled.
  public static let turnRateControlled = Self(rawValue: 1)

  /// Radius controlled.
  public static let radiusControlled = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 7)

  public var description: String {
    switch self {
    case .rudderLimitControlled: "rudder limit controlled"
    case .turnRateControlled: "turn rate controlled"
    case .radiusControlled: "radius controlled"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}
