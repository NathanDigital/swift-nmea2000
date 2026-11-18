// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

extension ParameterGroupCatalog {
  /// Every standard parameter group this library ports.
  ///
  /// The proprietary parameter groups aren't included, since other
  /// manufacturers use the same PGNs; add them with ``adding(_:)``, such as
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
}

extension Message {
  /// Decodes the message with the parameter group type for its PGN, or
  /// returns `nil` if the catalog has none.
  ///
  /// - Parameter catalog: The types to decode with.
  /// - Throws: An error from the type if it can't decode the message; the
  ///   types in this library throw ``MessageDecodingError``.
  public func decoded(
    using catalog: ParameterGroupCatalog = .standard
  ) throws -> (any ParameterGroup)? {
    try catalog.decode(self)
  }
}
