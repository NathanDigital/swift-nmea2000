// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A two-bit status: no, yes, error or unavailable.
///
/// Ports `tN2kDD002` (`tN2kGenericStatusPair`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct BinaryStatus: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
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

  /// Upstream's alias for ``no``.
  public static let off = Self(rawValue: 0)

  /// Upstream's alias for ``yes``.
  public static let on = Self(rawValue: 1)

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

/// The source of a configured delay or limit value.
///
/// Ports `tN2kDD374` (`tN2kDelaySource`). Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct DelaySource: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// User defined.
  public static let userDefined = Self(rawValue: 0)

  /// Minimum defined.
  public static let minimumDefined = Self(rawValue: 1)

  /// Factory default.
  public static let factoryDefault = Self(rawValue: 2)

  /// Maximum supported.
  public static let maximumSupported = Self(rawValue: 3)

  /// Out of range.
  public static let outOfRange = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .userDefined: "user defined"
    case .minimumDefined: "minimum defined"
    case .factoryDefault: "factory default"
    case .maximumSupported: "maximum supported"
    case .outOfRange: "out of range"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// A two-bit on/off status.
///
/// Ports `tN2kOnOff`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct OnOffStatus: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Off.
  public static let off = Self(rawValue: 0)

  /// On.
  public static let on = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .off: "off"
    case .on: "on"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

extension Bool {
  /// Decodes a two-bit yes/no field from its low two bits: 0 is `false`, 1
  /// is `true`, and error (2) or not available (3) is `nil`.
  init?(twoBitFlag bits: UInt8) {
    switch bits & 0x03 {
    case 0: self = false
    case 1: self = true
    default: return nil
    }
  }
}

extension Bool? {
  /// The value as a two-bit yes/no field: 0, 1, or 3 for not available.
  var twoBitFlag: UInt8 {
    switch self {
    case false?: 0
    case true?: 1
    case nil: 3
    }
  }
}

/// Describes a set of flags: the names of the flags that are set, then any
/// other bits as a raw value, such as `[warning level 1, unknown (0x100)]`.
func flagDescription<RawValue: FixedWidthInteger>(
  _ rawValue: RawValue, _ names: [(RawValue, String)]
) -> String {
  var remaining = rawValue
  var parts: [String] = []
  for (bits, name) in names where bits != 0 && rawValue & bits == bits {
    parts.append(name)
    remaining &= ~bits
  }
  if remaining != 0 { parts.append("unknown (0x\(String(remaining, radix: 16)))") }
  return "[" + parts.joined(separator: ", ") + "]"
}
