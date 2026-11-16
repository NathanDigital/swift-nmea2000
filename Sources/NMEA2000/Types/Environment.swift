// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// What a temperature measurement represents.
///
/// Ports `tN2kTempSource`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct TemperatureSource: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Sea.
  public static let sea = Self(rawValue: 0)

  /// Outside.
  public static let outside = Self(rawValue: 1)

  /// Inside.
  public static let inside = Self(rawValue: 2)

  /// Engine room.
  public static let engineRoom = Self(rawValue: 3)

  /// Main cabin.
  public static let mainCabin = Self(rawValue: 4)

  /// Live well.
  public static let liveWell = Self(rawValue: 5)

  /// Bait well.
  public static let baitWell = Self(rawValue: 6)

  /// Refrigeration.
  public static let refrigeration = Self(rawValue: 7)

  /// Heating system.
  public static let heatingSystem = Self(rawValue: 8)

  /// Dew point.
  public static let dewPoint = Self(rawValue: 9)

  /// Apparent wind chill.
  public static let apparentWindChill = Self(rawValue: 10)

  /// Theoretical wind chill.
  public static let theoreticalWindChill = Self(rawValue: 11)

  /// Heat index.
  public static let heatIndex = Self(rawValue: 12)

  /// Freezer.
  public static let freezer = Self(rawValue: 13)

  /// Exhaust gas.
  public static let exhaustGas = Self(rawValue: 14)

  /// Shaft seal.
  public static let shaftSeal = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .sea: "sea"
    case .outside: "outside"
    case .inside: "inside"
    case .engineRoom: "engine room"
    case .mainCabin: "main cabin"
    case .liveWell: "live well"
    case .baitWell: "bait well"
    case .refrigeration: "refrigeration"
    case .heatingSystem: "heating system"
    case .dewPoint: "dew point"
    case .apparentWindChill: "apparent wind chill"
    case .theoreticalWindChill: "theoretical wind chill"
    case .heatIndex: "heat index"
    case .freezer: "freezer"
    case .exhaustGas: "exhaust gas"
    case .shaftSeal: "shaft seal"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Where a humidity measurement is taken.
///
/// Ports `tN2kHumiditySource`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct HumiditySource: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Inside.
  public static let inside = Self(rawValue: 0)

  /// Outside.
  public static let outside = Self(rawValue: 1)

  /// Undefined.
  public static let undefined = Self(rawValue: 255)

  public var description: String {
    switch self {
    case .inside: "inside"
    case .outside: "outside"
    case .undefined: "undefined"
    default: "unknown (\(rawValue))"
    }
  }
}

/// What a pressure measurement represents.
///
/// Ports `tN2kPressureSource`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct PressureSource: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Atmospheric.
  public static let atmospheric = Self(rawValue: 0)

  /// Water.
  public static let water = Self(rawValue: 1)

  /// Steam.
  public static let steam = Self(rawValue: 2)

  /// Compressed air.
  public static let compressedAir = Self(rawValue: 3)

  /// Hydraulic.
  public static let hydraulic = Self(rawValue: 4)

  /// Filter.
  public static let filter = Self(rawValue: 5)

  /// Altimeter setting.
  public static let altimeterSetting = Self(rawValue: 6)

  /// Oil.
  public static let oil = Self(rawValue: 7)

  /// Fuel.
  public static let fuel = Self(rawValue: 8)

  /// An error.
  public static let error = Self(rawValue: 254)

  /// Not available.
  public static let unavailable = Self(rawValue: 255)

  public var description: String {
    switch self {
    case .atmospheric: "atmospheric"
    case .water: "water"
    case .steam: "steam"
    case .compressedAir: "compressed air"
    case .hydraulic: "hydraulic"
    case .filter: "filter"
    case .altimeterSetting: "altimeter setting"
    case .oil: "oil"
    case .fuel: "fuel"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The fluid a tank holds.
///
/// Ports `tN2kFluidType`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct FluidType: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Fuel.
  public static let fuel = Self(rawValue: 0)

  /// Water.
  public static let water = Self(rawValue: 1)

  /// Gray water.
  public static let grayWater = Self(rawValue: 2)

  /// Live well.
  public static let liveWell = Self(rawValue: 3)

  /// Oil.
  public static let oil = Self(rawValue: 4)

  /// Black water.
  public static let blackWater = Self(rawValue: 5)

  /// Gasoline.
  public static let gasoline = Self(rawValue: 6)

  /// An error.
  public static let error = Self(rawValue: 14)

  /// Not available.
  public static let unavailable = Self(rawValue: 15)

  public var description: String {
    switch self {
    case .fuel: "fuel"
    case .water: "water"
    case .grayWater: "gray water"
    case .liveWell: "live well"
    case .oil: "oil"
    case .blackWater: "black water"
    case .gasoline: "gasoline"
    case .error: "error"
    case .unavailable: "unavailable"
    default: "unknown (\(rawValue))"
    }
  }
}
