// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The mode a navigation value was produced in.
///
/// Ports `tN2kDD025` (`tN2kDataMode`). Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct DataMode: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Autonomous.
  public static let autonomous = Self(rawValue: 0)

  /// Differential.
  public static let differential = Self(rawValue: 1)

  /// Estimated.
  public static let estimated = Self(rawValue: 2)

  /// Simulator.
  public static let simulator = Self(rawValue: 3)

  /// Manual.
  public static let manual = Self(rawValue: 4)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .autonomous: "autonomous"
    case .differential: "differential"
    case .estimated: "estimated"
    case .simulator: "simulator"
    case .manual: "manual"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// When GNSS range residuals were calculated.
///
/// Ports `tN2kDD072` (`tN2kRangeResidualMode`). Values without a name here are kept in
/// ``rawValue``, so they decode and re-encode unchanged.
public struct RangeResidualMode: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Used to calculate position.
  public static let usedToCalculatePosition = Self(rawValue: 0)

  /// Calculated after position.
  public static let calculatedAfterPosition = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .usedToCalculatePosition: "used to calculate position"
    case .calculatedAfterPosition: "calculated after position"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// How a satellite is used in the GNSS solution.
///
/// Ports `tN2kDD124` (`tN2kPRNUsageStatus`). Values without a name here are kept in ``rawValue``,
/// so they decode and re-encode unchanged.
public struct PRNUsageStatus: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Not tracked.
  public static let notTracked = Self(rawValue: 0)

  /// Tracked but not used in solution.
  public static let trackedNotUsed = Self(rawValue: 1)

  /// Used without differential corrections.
  public static let usedWithoutDifferentialCorrections = Self(rawValue: 2)

  /// Differential corrections available.
  public static let differentialCorrectionsAvailable = Self(rawValue: 3)

  /// Tracked with differential corrections.
  public static let trackedWithDifferentialCorrections = Self(rawValue: 4)

  /// Used with differential corrections.
  public static let usedWithDifferentialCorrections = Self(rawValue: 5)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .notTracked: "not tracked"
    case .trackedNotUsed: "tracked but not used in solution"
    case .usedWithoutDifferentialCorrections: "used without differential corrections"
    case .differentialCorrectionsAvailable: "differential corrections available"
    case .trackedWithDifferentialCorrections: "tracked with differential corrections"
    case .usedWithDifferentialCorrections: "used with differential corrections"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The satellite systems a GNSS position is derived from.
///
/// Ports `tN2kGNSStype`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct GNSSType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// GPS.
  public static let gps = Self(rawValue: 0)

  /// GLONASS.
  public static let glonass = Self(rawValue: 1)

  /// GPS+GLONASS.
  public static let gpsGLONASS = Self(rawValue: 2)

  /// GPS+SBAS/WAAS.
  public static let gpsSBAS = Self(rawValue: 3)

  /// GPS+SBAS/WAAS+GLONASS.
  public static let gpsSBASGLONASS = Self(rawValue: 4)

  /// Chayka.
  public static let chayka = Self(rawValue: 5)

  /// Integrated.
  public static let integrated = Self(rawValue: 6)

  /// Surveyed.
  public static let surveyed = Self(rawValue: 7)

  /// Galileo.
  public static let galileo = Self(rawValue: 8)

  public var description: String {
    switch self {
    case .gps: "GPS"
    case .glonass: "GLONASS"
    case .gpsGLONASS: "GPS+GLONASS"
    case .gpsSBAS: "GPS+SBAS/WAAS"
    case .gpsSBASGLONASS: "GPS+SBAS/WAAS+GLONASS"
    case .chayka: "Chayka"
    case .integrated: "integrated"
    case .surveyed: "surveyed"
    case .galileo: "Galileo"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The method used to obtain a GNSS fix.
///
/// Ports `tN2kGNSSmethod`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct GNSSMethod: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// No GNSS.
  public static let noGNSS = Self(rawValue: 0)

  /// GNSS fix.
  public static let gnssFix = Self(rawValue: 1)

  /// DGNSS.
  public static let dgnss = Self(rawValue: 2)

  /// Precise GNSS.
  public static let preciseGNSS = Self(rawValue: 3)

  /// RTK fixed.
  public static let rtkFixed = Self(rawValue: 4)

  /// RTK float.
  public static let rtkFloat = Self(rawValue: 5)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .noGNSS: "no GNSS"
    case .gnssFix: "GNSS fix"
    case .dgnss: "DGNSS"
    case .preciseGNSS: "precise GNSS"
    case .rtkFixed: "RTK fixed"
    case .rtkFloat: "RTK float"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The dimension mode used for dilution of precision.
///
/// Ports `tN2kGNSSDOPmode`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct GNSSDOPMode: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// 1D.
  public static let oneDimensional = Self(rawValue: 0)

  /// 2D.
  public static let twoDimensional = Self(rawValue: 1)

  /// 3D.
  public static let threeDimensional = Self(rawValue: 2)

  /// Automatic.
  public static let automatic = Self(rawValue: 3)

  /// An error.
  public static let error = Self(rawValue: 6)

  /// Not available.
  public static let unavailable = Self(rawValue: 7)

  public var description: String {
    switch self {
    case .oneDimensional: "1D"
    case .twoDimensional: "2D"
    case .threeDimensional: "3D"
    case .automatic: "automatic"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}
