# Field value types

Find the types for enumerated fields and flag sets.

## Overview

An enumerated field is a struct conforming to ``WireEnumeration``, with a static property for
each value the original library names. A value without a name decodes into `rawValue` and is
sent back unchanged, so a `switch` over one of these types needs a `default` case. Sets of
flags are `OptionSet` types.

## Topics

### Common

- ``BinaryStatus``
- ``OnOffStatus``
- ``DelaySource``

### Navigation

- ``NavigationDirection``
- ``HeadingReference``
- ``DistanceCalculationType``
- ``CrossTrackErrorMode``
- ``TimeSource``
- ``WindReference``
- ``SpeedWaterReferenceType``
- ``MagneticVariationSource``

### GNSS

- ``DataMode``
- ``RangeResidualMode``
- ``PRNUsageStatus``
- ``GNSSType``
- ``GNSSMethod``
- ``GNSSDOPMode``

### Steering

- ``RudderDirectionOrder``
- ``SteeringMode``
- ``TurnMode``

### Man overboard

- ``MOBStatus``
- ``MOBPositionSource``
- ``MOBEmitterBatteryStatus``

### Engines, transmissions and thrusters

- ``ThrusterDirectionControl``
- ``ThrusterRetraction``
- ``MotorPowerType``
- ``MotorSpeedType``
- ``TransmissionGear``
- ``EngineDiscreteStatus``
- ``EngineWarningStatus``
- ``ThrusterMotorEvents``
- ``ThrusterControlEvents``
- ``TransmissionDiscreteStatus``

### Batteries, chargers and converters

- ``DCSourceType``
- ``BatteryType``
- ``BatteryEqualizationSupport``
- ``BatteryChemistry``
- ``BatteryNominalVoltage``
- ``ChargeState``
- ``ChargerMode``
- ``ConverterOperatingState``
- ``RippleState``
- ``DCVoltageState``
- ``OverloadState``
- ``TemperatureState``
- ``ChargingAlgorithm``
- ``BatteryTemperatureEstimate``

### Windlass

- ``WindlassMotionState``
- ``RodeType``
- ``AnchorDockingState``
- ``WindlassDirectionControl``
- ``WindlassMonitoringEvents``
- ``WindlassControlEvents``
- ``WindlassOperatingEvents``

### AIS

- ``AISAtoNType``
- ``AISRepeatIndicator``
- ``AISVersion``
- ``AISNavigationStatus``
- ``AISDTEStatus``
- ``AISUnitType``
- ``AISMode``
- ``AISTransceiverInformation``

### Environment and fluids

- ``TemperatureSource``
- ``HumiditySource``
- ``PressureSource``
- ``FluidType``
