// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The type of an AIS aid to navigation.
///
/// Ports `tN2kDD305` (`tN2kAISAtoNType`). Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct AISAtoNType: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Not specified.
  public static let notSpecified = Self(rawValue: 0)

  /// Reference point.
  public static let referencePoint = Self(rawValue: 1)

  /// RACON.
  public static let racon = Self(rawValue: 2)

  /// Fixed structure.
  public static let fixedStructure = Self(rawValue: 3)

  /// Emergency wreck marking buoy.
  public static let emergencyWreckMarkingBuoy = Self(rawValue: 4)

  /// Light without sectors.
  public static let lightWithoutSectors = Self(rawValue: 5)

  /// Light with sectors.
  public static let lightWithSectors = Self(rawValue: 6)

  /// Leading light front.
  public static let leadingLightFront = Self(rawValue: 7)

  /// Leading light rear.
  public static let leadingLightRear = Self(rawValue: 8)

  /// Beacon, cardinal north.
  public static let beaconCardinalNorth = Self(rawValue: 9)

  /// Beacon, cardinal east.
  public static let beaconCardinalEast = Self(rawValue: 10)

  /// Beacon, cardinal south.
  public static let beaconCardinalSouth = Self(rawValue: 11)

  /// Beacon, cardinal west.
  public static let beaconCardinalWest = Self(rawValue: 12)

  /// Beacon, port hand.
  public static let beaconPortHand = Self(rawValue: 13)

  /// Beacon, starboard hand.
  public static let beaconStarboardHand = Self(rawValue: 14)

  /// Beacon, preferred channel port hand.
  public static let beaconPreferredChannelPortHand = Self(rawValue: 15)

  /// Beacon, preferred channel starboard hand.
  public static let beaconPreferredChannelStarboardHand = Self(rawValue: 16)

  /// Beacon, isolated danger.
  public static let beaconIsolatedDanger = Self(rawValue: 17)

  /// Beacon, safe water.
  public static let beaconSafeWater = Self(rawValue: 18)

  /// Beacon, special mark.
  public static let beaconSpecialMark = Self(rawValue: 19)

  /// Cardinal mark north.
  public static let cardinalMarkNorth = Self(rawValue: 20)

  /// Cardinal mark east.
  public static let cardinalMarkEast = Self(rawValue: 21)

  /// Cardinal mark south.
  public static let cardinalMarkSouth = Self(rawValue: 22)

  /// Cardinal mark west.
  public static let cardinalMarkWest = Self(rawValue: 23)

  /// Port hand mark.
  public static let portHandMark = Self(rawValue: 24)

  /// Starboard hand mark.
  public static let starboardHandMark = Self(rawValue: 25)

  /// Preferred channel port hand.
  public static let preferredChannelPortHand = Self(rawValue: 26)

  /// Preferred channel starboard hand.
  public static let preferredChannelStarboardHand = Self(rawValue: 27)

  /// Isolated danger.
  public static let isolatedDanger = Self(rawValue: 28)

  /// Safe water.
  public static let safeWater = Self(rawValue: 29)

  /// Special mark.
  public static let specialMark = Self(rawValue: 30)

  /// Light vessel, LANBY or rig.
  public static let lightVessel = Self(rawValue: 31)

  public var description: String {
    switch self {
    case .notSpecified: "not specified"
    case .referencePoint: "reference point"
    case .racon: "RACON"
    case .fixedStructure: "fixed structure"
    case .emergencyWreckMarkingBuoy: "emergency wreck marking buoy"
    case .lightWithoutSectors: "light without sectors"
    case .lightWithSectors: "light with sectors"
    case .leadingLightFront: "leading light front"
    case .leadingLightRear: "leading light rear"
    case .beaconCardinalNorth: "beacon, cardinal north"
    case .beaconCardinalEast: "beacon, cardinal east"
    case .beaconCardinalSouth: "beacon, cardinal south"
    case .beaconCardinalWest: "beacon, cardinal west"
    case .beaconPortHand: "beacon, port hand"
    case .beaconStarboardHand: "beacon, starboard hand"
    case .beaconPreferredChannelPortHand: "beacon, preferred channel port hand"
    case .beaconPreferredChannelStarboardHand: "beacon, preferred channel starboard hand"
    case .beaconIsolatedDanger: "beacon, isolated danger"
    case .beaconSafeWater: "beacon, safe water"
    case .beaconSpecialMark: "beacon, special mark"
    case .cardinalMarkNorth: "cardinal mark north"
    case .cardinalMarkEast: "cardinal mark east"
    case .cardinalMarkSouth: "cardinal mark south"
    case .cardinalMarkWest: "cardinal mark west"
    case .portHandMark: "port hand mark"
    case .starboardHandMark: "starboard hand mark"
    case .preferredChannelPortHand: "preferred channel port hand"
    case .preferredChannelStarboardHand: "preferred channel starboard hand"
    case .isolatedDanger: "isolated danger"
    case .safeWater: "safe water"
    case .specialMark: "special mark"
    case .lightVessel: "light vessel, LANBY or rig"
    default: "unknown (\(rawValue))"
    }
  }
}

/// How many times an AIS message has been repeated.
///
/// Ports `tN2kAISRepeat`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct AISRepeatIndicator: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Initial.
  public static let initial = Self(rawValue: 0)

  /// First.
  public static let first = Self(rawValue: 1)

  /// Second.
  public static let second = Self(rawValue: 2)

  /// Final.
  public static let final = Self(rawValue: 3)

  public var description: String {
    switch self {
    case .initial: "initial"
    case .first: "first"
    case .second: "second"
    case .final: "final"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The ITU-R M.1371 version an AIS transponder implements.
///
/// Ports `tN2kAISVersion`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct AISVersion: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// ITU-R M.1371-1.
  public static let ituRM1371v1 = Self(rawValue: 0)

  /// ITU-R M.1371-3.
  public static let ituRM1371v3 = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .ituRM1371v1: "ITU-R M.1371-1"
    case .ituRM1371v3: "ITU-R M.1371-3"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The navigational status a vessel reports over AIS.
///
/// Ports `tN2kAISNavStatus`. Values without a name here are kept in ``rawValue``, so they decode
/// and re-encode unchanged.
public struct AISNavigationStatus: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Under way motoring.
  public static let underWayMotoring = Self(rawValue: 0)

  /// At anchor.
  public static let atAnchor = Self(rawValue: 1)

  /// Not under command.
  public static let notUnderCommand = Self(rawValue: 2)

  /// Restricted maneuverability.
  public static let restrictedManeuverability = Self(rawValue: 3)

  /// Constrained by draught.
  public static let constrainedByDraught = Self(rawValue: 4)

  /// Moored.
  public static let moored = Self(rawValue: 5)

  /// Aground.
  public static let aground = Self(rawValue: 6)

  /// Fishing.
  public static let fishing = Self(rawValue: 7)

  /// Under way sailing.
  public static let underWaySailing = Self(rawValue: 8)

  /// Hazardous material, high speed.
  public static let hazardousMaterialHighSpeed = Self(rawValue: 9)

  /// Hazardous material, wing in ground.
  public static let hazardousMaterialWingInGround = Self(rawValue: 10)

  /// AIS-SART.
  public static let aisSART = Self(rawValue: 14)

  public var description: String {
    switch self {
    case .underWayMotoring: "under way motoring"
    case .atAnchor: "at anchor"
    case .notUnderCommand: "not under command"
    case .restrictedManeuverability: "restricted maneuverability"
    case .constrainedByDraught: "constrained by draught"
    case .moored: "moored"
    case .aground: "aground"
    case .fishing: "fishing"
    case .underWaySailing: "under way sailing"
    case .hazardousMaterialHighSpeed: "hazardous material, high speed"
    case .hazardousMaterialWingInGround: "hazardous material, wing in ground"
    case .aisSART: "AIS-SART"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Whether an AIS station's data terminal equipment is ready.
///
/// Ports `tN2kAISDTE`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct AISDTEStatus: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Ready.
  public static let ready = Self(rawValue: 0)

  /// Not ready.
  public static let notReady = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .ready: "ready"
    case .notReady: "not ready"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The access scheme of a class B AIS unit.
///
/// Ports `tN2kAISUnit`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct AISUnitType: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Class B SOTDMA.
  public static let classBSOTDMA = Self(rawValue: 0)

  /// Class B CS.
  public static let classBCS = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .classBSOTDMA: "class B SOTDMA"
    case .classBCS: "class B CS"
    default: "unknown (\(rawValue))"
    }
  }
}

/// Whether an AIS station is in autonomous or assigned mode.
///
/// Ports `tN2kAISMode`. Values without a name here are kept in ``rawValue``, so they decode and
/// re-encode unchanged.
public struct AISMode: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Autonomous.
  public static let autonomous = Self(rawValue: 0)

  /// Assigned.
  public static let assigned = Self(rawValue: 1)

  public var description: String {
    switch self {
    case .autonomous: "autonomous"
    case .assigned: "assigned"
    default: "unknown (\(rawValue))"
    }
  }
}

/// The AIS channel and direction a message used.
///
/// Ports `tN2kAISTransceiverInformation`. Values without a name here are kept in ``rawValue``, so
/// they decode and re-encode unchanged.
public struct AISTransceiverInformation: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
{
  /// The value as it appears on the wire.
  public var rawValue: UInt8

  /// Creates a value from its wire representation.
  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Channel A VDL reception.
  public static let channelAReception = Self(rawValue: 0)

  /// Channel B VDL reception.
  public static let channelBReception = Self(rawValue: 1)

  /// Channel A VDL transmission.
  public static let channelATransmission = Self(rawValue: 2)

  /// Channel B VDL transmission.
  public static let channelBTransmission = Self(rawValue: 3)

  /// Own information not broadcast.
  public static let ownInformationNotBroadcast = Self(rawValue: 4)

  public var description: String {
    switch self {
    case .channelAReception: "channel A VDL reception"
    case .channelBReception: "channel B VDL reception"
    case .channelATransmission: "channel A VDL transmission"
    case .channelBTransmission: "channel B VDL transmission"
    case .ownInformationNotBroadcast: "own information not broadcast"
    default: "unknown (\(rawValue))"
    }
  }
}
