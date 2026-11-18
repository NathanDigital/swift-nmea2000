// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The direction a vessel is navigating a route.
///
/// Ports `tN2kNavigationDirection`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct NavigationDirection: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Forward.
  public static let forward = Self(rawValue: 0)

  /// Reverse.
  public static let reverse = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 6)

  /// Unknown.
  public static let unknown = Self(rawValue: 7)

  public var description: String {
    switch self {
    case .forward: "forward"
    case .reverse: "reverse"
    case .error: "error"
    case .unknown: "unknown"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The reference a heading or bearing is measured from.
///
/// Ports `tN2kHeadingReference`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct HeadingReference: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// True.
  public static let `true` = Self(rawValue: 0)

  /// Magnetic.
  public static let magnetic = Self(rawValue: 1)

  /// An error.
  public static let error = Self(rawValue: 2)

  /// Not available.
  public static let unavailable = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .`true`: "true"
    case .magnetic: "magnetic"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The method used to calculate a distance.
///
/// Ports `tN2kDistanceCalculationType`. Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct DistanceCalculationType: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Great circle.
  public static let greatCircle = Self(rawValue: 0)

  /// Rhumb line.
  public static let rhumbLine = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .greatCircle: "great circle"
    case .rhumbLine: "rhumb line"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The mode a cross-track error was calculated in.
///
/// Ports `tN2kXTEMode`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct CrossTrackErrorMode: WireEnumeration {
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

  public var description: String {
    switch self {
    case .autonomous: "autonomous"
    case .differential: "differential"
    case .estimated: "estimated"
    case .simulator: "simulator"
    case .manual: "manual"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The source of a system time.
///
/// Ports `tN2kTimeSource`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct TimeSource: WireEnumeration {
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

  /// Radio station.
  public static let radioStation = Self(rawValue: 2)

  /// Local cesium clock.
  public static let localCesiumClock = Self(rawValue: 3)

  /// Local rubidium clock.
  public static let localRubidiumClock = Self(rawValue: 4)

  /// Local crystal clock.
  public static let localCrystalClock = Self(rawValue: 5)

  public var description: String {
    switch self {
    case .gps: "GPS"
    case .glonass: "GLONASS"
    case .radioStation: "radio station"
    case .localCesiumClock: "local cesium clock"
    case .localRubidiumClock: "local rubidium clock"
    case .localCrystalClock: "local crystal clock"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The reference a wind direction and speed are given in.
///
/// Ports `tN2kWindReference`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct WindReference: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// True, referenced to true north.
  public static let trueNorth = Self(rawValue: 0)

  /// True, referenced to magnetic north.
  public static let magnetic = Self(rawValue: 1)

  /// Apparent.
  public static let apparent = Self(rawValue: 2)

  /// True, referenced to the vessel centerline over ground.
  public static let trueBoat = Self(rawValue: 3)

  /// True, referenced to the vessel centerline through water.
  public static let trueWater = Self(rawValue: 4)

  /// An error.
  public static let error = Self(rawValue: 6)

  /// Not available.
  public static let unavailable = Self(rawValue: 7)

  public var description: String {
    switch self {
    case .trueNorth: "true, referenced to true north"
    case .magnetic: "true, referenced to magnetic north"
    case .apparent: "apparent"
    case .trueBoat: "true, referenced to the vessel centerline over ground"
    case .trueWater: "true, referenced to the vessel centerline through water"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The kind of sensor that measures speed through water.
///
/// Ports `tN2kSpeedWaterReferenceType`. Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct SpeedWaterReferenceType: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Paddle wheel.
  public static let paddleWheel = Self(rawValue: 0)

  /// Pitot tube.
  public static let pitotTube = Self(rawValue: 1)

  /// Doppler log.
  public static let dopplerLog = Self(rawValue: 2)

  /// Ultrasound.
  public static let ultrasound = Self(rawValue: 3)

  /// Electromagnetic.
  public static let electromagnetic = Self(rawValue: 4)

  /// An error.
  public static let error = Self(rawValue: 254)

  /// Not available.
  public static let unavailable = Self(rawValue: 255)

  public var description: String {
    switch self {
    case .paddleWheel: "paddle wheel"
    case .pitotTube: "pitot tube"
    case .dopplerLog: "Doppler log"
    case .ultrasound: "ultrasound"
    case .electromagnetic: "electromagnetic"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The source of a magnetic variation value.
///
/// Ports `tN2kMagneticVariation`. Values without a name here are kept in ``rawValue``, so they
/// decode and re-encode unchanged.
public struct MagneticVariationSource: WireEnumeration {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Manual.
  public static let manual = Self(rawValue: 0)

  /// Chart.
  public static let chart = Self(rawValue: 1)

  /// Table.
  public static let table = Self(rawValue: 2)

  /// Calculated.
  public static let calculated = Self(rawValue: 3)

  /// WMM 2000.
  public static let wmm2000 = Self(rawValue: 4)

  /// WMM 2005.
  public static let wmm2005 = Self(rawValue: 5)

  /// WMM 2010.
  public static let wmm2010 = Self(rawValue: 6)

  /// WMM 2015.
  public static let wmm2015 = Self(rawValue: 7)

  /// WMM 2020.
  public static let wmm2020 = Self(rawValue: 8)

  /// WMM 2025.
  public static let wmm2025 = Self(rawValue: 9)

  public var description: String {
    switch self {
    case .manual: "manual"
    case .chart: "chart"
    case .table: "table"
    case .calculated: "calculated"
    case .wmm2000: "WMM 2000"
    case .wmm2005: "WMM 2005"
    case .wmm2010: "WMM 2010"
    case .wmm2015: "WMM 2015"
    case .wmm2020: "WMM 2020"
    case .wmm2025: "WMM 2025"
    default: "unknown (\(rawValue))"
    }
  }
}
