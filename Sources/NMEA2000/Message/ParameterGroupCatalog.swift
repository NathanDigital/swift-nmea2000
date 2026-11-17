// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Parameter group types by PGN, for decoding received messages without
/// switching on their PGNs.
///
/// ```swift
/// for await message in await node.messages() {
///   switch try? message.decoded() {
///   case let position as PositionRapidUpdate: show(position)
///   case let wind as WindData: show(wind)
///   default: break
///   }
/// }
/// ```
///
/// To receive one type only,
/// ``Node/messages(of:includingSent:bufferingPolicy:)`` is simpler.
public struct ParameterGroupCatalog: Sendable {
  /// The types, by PGN.
  public private(set) var types: [UInt32: any ParameterGroup.Type]

  /// Creates a catalog of types. Of types with the same PGN, the last
  /// counts.
  public init(_ types: [any ParameterGroup.Type]) {
    self.types = [:]
    add(types)
  }

  /// Adds types, replacing any with the same PGN.
  public mutating func add(_ types: [any ParameterGroup.Type]) {
    for type in types { self.types[type.pgn] = type }
  }

  /// Decodes a message with the type for its PGN, or returns `nil` if the
  /// catalog has none.
  ///
  /// - Throws: ``MessageDecodingError`` if the type can't decode it.
  public func decode(_ message: Message) throws(MessageDecodingError) -> (any ParameterGroup)? {
    guard let type = types[message.pgn] else { return nil }
    return try type.init(message)
  }

  /// Every standard parameter group this library ports.
  ///
  /// The proprietary parameter groups aren't included, since other
  /// manufacturers use the same PGNs; add them with ``add(_:)``, such as
  /// ``maretron``.
  public static let standard = ParameterGroupCatalog([
    ActualPressure.self,
    AISAtoNReport.self,
    AISClassAPositionReport.self,
    AISClassAStaticData.self,
    AISClassBPositionReport.self,
    AISClassBStaticDataPartA.self,
    AISClassBStaticDataPartB.self,
    AISSafetyRelatedBroadcast.self,
    Attitude.self,
    BatteryConfigurationStatus.self,
    BatteryStatus.self,
    BinarySwitchBankStatus.self,
    BoatSpeed.self,
    ChargerConfigurationStatus.self,
    ChargerStatus.self,
    COGSOGRapidUpdate.self,
    ConfigurationInformation.self,
    ConverterStatus.self,
    CrossTrackError.self,
    DCDetailedStatus.self,
    DCVoltageCurrent.self,
    DirectionData.self,
    DistanceLog.self,
    EngineParametersDynamic.self,
    EngineParametersRapid.self,
    EngineTripParameters.self,
    EnvironmentalParameters.self,
    FluidLevel.self,
    GNSSDOPData.self,
    GNSSPositionData.self,
    GNSSSatellitesInView.self,
    HeadingTrackControl.self,
    Heartbeat.self,
    Heave.self,
    Humidity.self,
    ISOAcknowledgement.self,
    ISOAddressClaim.self,
    ISORequest.self,
    Leeway.self,
    MagneticVariation.self,
    ManOverboardNotification.self,
    MeteorologicalStationData.self,
    NavigationInfo.self,
    OutsideEnvironmentalParameters.self,
    PGNList.self,
    PositionRapidUpdate.self,
    ProductInformation.self,
    RateOfTurn.self,
    RouteWaypointInformation.self,
    Rudder.self,
    SetPressure.self,
    SwitchBankControl.self,
    SystemTime.self,
    Temperature.self,
    TemperatureExtendedRange.self,
    TimeAndDate.self,
    TransmissionParameters.self,
    TrimTabStatus.self,
    VesselHeading.self,
    WaterDepth.self,
    WaypointList.self,
    WindData.self,
    WindlassControlStatus.self,
    WindlassMonitoringStatus.self,
    WindlassOperatingStatus.self,
  ])

  /// The Maretron parameter groups.
  public static let maretron: [any ParameterGroup.Type] = [
    MaretronTemperatureHighRange.self, MaretronFluidFlowRate.self, MaretronTripVolume.self,
  ]
}

extension Message {
  /// Decodes the message with the parameter group type for its PGN, or
  /// returns `nil` if the catalog has none.
  ///
  /// - Parameter catalog: The types to decode with.
  /// - Throws: ``MessageDecodingError`` if the type can't decode it.
  public func decoded(
    using catalog: ParameterGroupCatalog = .standard
  ) throws(MessageDecodingError) -> (any ParameterGroup)? {
    try catalog.decode(self)
  }
}
