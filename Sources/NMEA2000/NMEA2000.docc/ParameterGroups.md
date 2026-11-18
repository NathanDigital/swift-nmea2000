# Parameter groups

Find the type for a PGN.

## Overview

Each type's summary starts with its PGN, and each source file is named for it, such as
`PGN129025PositionRapidUpdate.swift`. The types here are the PGNs the original library
supports; to add one of your own, see <doc:DecodingAndEncodingMessages>.

## Topics

### Network management

- ``ISOAcknowledgement``
- ``ISORequest``
- ``ISOAddressClaim``
- ``PGNList``
- ``Heartbeat``
- ``ProductInformation``
- ``ConfigurationInformation``

### Time

- ``SystemTime``
- ``TimeAndDate``

### Heading, speed and depth

- ``VesselHeading``
- ``RateOfTurn``
- ``Heave``
- ``Attitude``
- ``MagneticVariation``
- ``Leeway``
- ``BoatSpeed``
- ``WaterDepth``
- ``DistanceLog``
- ``DirectionData``

### Position and satellites

- ``PositionRapidUpdate``
- ``COGSOGRapidUpdate``
- ``GNSSPositionData``
- ``GNSSDOPData``
- ``GNSSSatellitesInView``

### Routes and waypoints

- ``CrossTrackError``
- ``NavigationInfo``
- ``RouteWaypointInformation``
- ``WaypointList``
- ``Waypoint``

### Steering

- ``HeadingTrackControl``
- ``Rudder``
- ``TrimTabStatus``

### Man overboard

- ``ManOverboardNotification``

### Engines and transmissions

- ``EngineParametersRapid``
- ``EngineParametersDynamic``
- ``TransmissionParameters``
- ``EngineTripParameters``

### Switches and tanks

- ``BinarySwitchBankStatus``
- ``SwitchBankControl``
- ``FluidLevel``

### Batteries, chargers and converters

- ``DCDetailedStatus``
- ``ChargerStatus``
- ``BatteryStatus``
- ``ChargerConfigurationStatus``
- ``BatteryConfigurationStatus``
- ``ConverterStatus``
- ``DCVoltageCurrent``

### Windlass

- ``WindlassControlStatus``
- ``WindlassOperatingStatus``
- ``WindlassMonitoringStatus``

### AIS

- ``AISClassAPositionReport``
- ``AISClassBPositionReport``
- ``AISAtoNReport``
- ``AISClassAStaticData``
- ``AISSafetyRelatedBroadcast``
- ``AISClassBStaticDataPartA``
- ``AISClassBStaticDataPartB``

### Wind and environment

- ``WindData``
- ``OutsideEnvironmentalParameters``
- ``EnvironmentalParameters``
- ``Temperature``
- ``Humidity``
- ``ActualPressure``
- ``SetPressure``
- ``TemperatureExtendedRange``
- ``MeteorologicalStationData``

### Proprietary

- ``MaretronTemperatureHighRange``
- ``MaretronFluidFlowRate``
- ``MaretronTripVolume``
- ``CZoneSwitchStatus``
