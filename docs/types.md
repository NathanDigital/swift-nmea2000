# Enumerated field types: upstream → Swift mapping

Upstream's `tN2k…` enums (`src/N2kTypes.h`) and data dictionary types (`tN2kDD…`, `src/NMEA2000StdTypes.h`) are ported to `Sources/NMEA2000/Types/`, grouped by domain.

## Representation

- **Enums** become `RawRepresentable` structs with a `UInt8` raw value and a `static let` for each upstream value, e.g. `HeadingReference.magnetic`. A struct is used instead of a Swift `enum` because decoding must never fail on a value we don't know. Newer devices send codes that upstream doesn't name, and those are kept in `rawValue` and re-encoded unchanged. Use `switch` with a `default:` case.
- **Bit-field unions** (`tN2kDD206`, `tN2kDD471`, …) become `OptionSet`s with upstream's bit positions.
- **Raw values** are identical to upstream's. Reserved values that upstream names (e.g. `N2kdir_reserved1`) aren't given names; they still round-trip through `rawValue`.
- **Aliases:** upstream's alternative names for a single value (`N2kDD002_Off`, `N2kWind_Apprent`, …) are dropped, except `BinaryStatus.off` / `.on`.
- **Descriptions:** every type is `CustomStringConvertible`. The strings are written for this port, not copied from `N2kMessagesEnumToStr.h`, whose tables are incomplete and in places wrong (for example, `tN2kMagneticVariation` uses the speed-sensor table). Unknown values print as `unknown (<raw value>)`.

## Deliberate divergences

- `tN2kDCVolgateState::N2kDCVS_Low` and `tN2kTemperatureState::N2kTS_High` are 3 upstream, the same value as `NotAvailable`, so sending them puts "not available" on the bus. Canboat defines all four converter state fields of PGN 127750 with one lookup (`GOOD_WARNING_ERROR`: 0 good, 1 warning, 2 error), and upstream's own `N2kOS_Overload` and `N2kRP_High` are 2. This port defines `DCVoltageState.low` and `TemperatureState.high` as 2.

- `tN2kBatNomVolt::N2kDCbnv_62v` (code 4) is named `BatteryNominalVoltage.volts36`. Canboat defines code 4 as 36 V (corrected in canboat issue #143 from Maretron's DCM100 user manual, whose appendix lists "4=36 Volts"), and 62 V isn't a nominal battery voltage. The value sent is unchanged.

## Upstream quirks kept

- `tN2kDD223` (`EngineDiscreteStatus2`) keeps only the low eight bits when assigned in upstream, and `tN2kDD471`'s `SetEvents` clears bit 6. These are applied in the PGN ports that use them, not in the types.

## Mapping

| Upstream | Swift | File |
|---|---|---|
| `tN2kDD305` / `tN2kAISAtoNType` | `AISAtoNType` | `AIS.swift` |
| `tN2kAISDTE` | `AISDTEStatus` | `AIS.swift` |
| `tN2kAISMode` | `AISMode` | `AIS.swift` |
| `tN2kAISNavStatus` | `AISNavigationStatus` | `AIS.swift` |
| `tN2kAISRepeat` | `AISRepeatIndicator` | `AIS.swift` |
| `tN2kAISTransceiverInformation` | `AISTransceiverInformation` | `AIS.swift` |
| `tN2kAISUnit` | `AISUnitType` | `AIS.swift` |
| `tN2kAISVersion` | `AISVersion` | `AIS.swift` |
| `tN2kDD002` / `tN2kGenericStatusPair` | `BinaryStatus` | `Common.swift` |
| `tN2kDD374` / `tN2kDelaySource` | `DelaySource` | `Common.swift` |
| `tN2kOnOff` | `OnOffStatus` | `Common.swift` |
| `tN2kBatChem` | `BatteryChemistry` | `Electrical.swift` |
| `tN2kBatEqSupport` | `BatteryEqualizationSupport` | `Electrical.swift` |
| `tN2kBatNomVolt` | `BatteryNominalVoltage` | `Electrical.swift` |
| `tBattTempNoSensor` | `BatteryTemperatureEstimate` | `Electrical.swift` |
| `tN2kBatType` | `BatteryType` | `Electrical.swift` |
| `tN2kChargeState` | `ChargeState` | `Electrical.swift` |
| `tN2kChargerMode` | `ChargerMode` | `Electrical.swift` |
| `tN2kChargingAlgorithm` | `ChargingAlgorithm` | `Electrical.swift` |
| `tN2kConvMode` | `ConverterOperatingState` | `Electrical.swift` |
| `tN2kDCType` | `DCSourceType` | `Electrical.swift` |
| `tN2kDCVolgateState` | `DCVoltageState` | `Electrical.swift` |
| `tN2kOverloadState` | `OverloadState` | `Electrical.swift` |
| `tN2kRippleState` | `RippleState` | `Electrical.swift` |
| `tN2kTemperatureState` | `TemperatureState` | `Electrical.swift` |
| `tN2kFluidType` | `FluidType` | `Environment.swift` |
| `tN2kHumiditySource` | `HumiditySource` | `Environment.swift` |
| `tN2kPressureSource` | `PressureSource` | `Environment.swift` |
| `tN2kTempSource` | `TemperatureSource` | `Environment.swift` |
| `tN2kDD025` / `tN2kDataMode` | `DataMode` | `GNSS.swift` |
| `tN2kGNSSDOPmode` | `GNSSDOPMode` | `GNSS.swift` |
| `tN2kGNSSmethod` | `GNSSMethod` | `GNSS.swift` |
| `tN2kGNSStype` | `GNSSType` | `GNSS.swift` |
| `tN2kDD124` / `tN2kPRNUsageStatus` | `PRNUsageStatus` | `GNSS.swift` |
| `tN2kDD072` / `tN2kRangeResidualMode` | `RangeResidualMode` | `GNSS.swift` |
| `tN2kMOBEmitterBatteryStatus` | `MOBEmitterBatteryStatus` | `MOB.swift` |
| `tN2kMOBPositionSource` | `MOBPositionSource` | `MOB.swift` |
| `tN2kMOBStatus` | `MOBStatus` | `MOB.swift` |
| `tN2kXTEMode` | `CrossTrackErrorMode` | `Navigation.swift` |
| `tN2kDistanceCalculationType` | `DistanceCalculationType` | `Navigation.swift` |
| `tN2kHeadingReference` | `HeadingReference` | `Navigation.swift` |
| `tN2kMagneticVariation` | `MagneticVariationSource` | `Navigation.swift` |
| `tN2kNavigationDirection` | `NavigationDirection` | `Navigation.swift` |
| `tN2kSpeedWaterReferenceType` | `SpeedWaterReferenceType` | `Navigation.swift` |
| `tN2kTimeSource` | `TimeSource` | `Navigation.swift` |
| `tN2kWindReference` | `WindReference` | `Navigation.swift` |
| `tN2kDD487` / `tN2kMotorPowerType` | `MotorPowerType` | `Propulsion.swift` |
| `tN2kDD488` / `tN2kSpeedType` | `MotorSpeedType` | `Propulsion.swift` |
| `tN2kDD473` / `tN2kThrusterDirectionControl` | `ThrusterDirectionControl` | `Propulsion.swift` |
| `tN2kDD474` / `tN2kThrusterRetraction` | `ThrusterRetraction` | `Propulsion.swift` |
| `tN2kTransmissionGear` | `TransmissionGear` | `Propulsion.swift` |
| `tN2kRudderDirectionOrder` | `RudderDirectionOrder` | `Steering.swift` |
| `tN2kSteeringMode` | `SteeringMode` | `Steering.swift` |
| `tN2kTurnMode` | `TurnMode` | `Steering.swift` |
| `tN2kDD482` / `tN2kAnchorDockingStates` | `AnchorDockingState` | `Windlass.swift` |
| `tN2kDD481` / `tN2kRodeTypeStates` | `RodeType` | `Windlass.swift` |
| `tN2kDD484` / `tN2kWindlassDirectionControl` | `WindlassDirectionControl` | `Windlass.swift` |
| `tN2kDD480` / `tN2kWindlassMotionStates` | `WindlassMotionState` | `Windlass.swift` |
| `tN2kDD206` / `tN2kEngineDiscreteStatus1` | `EngineDiscreteStatus1` (`OptionSet`) | `Propulsion.swift` |
| `tN2kDD223` / `tN2kEngineDiscreteStatus2` | `EngineDiscreteStatus2` (`OptionSet`) | `Propulsion.swift` |
| `tN2kDD471` / `tN2kThrusterMotorEvents` | `ThrusterMotorEvents` (`OptionSet`) | `Propulsion.swift` |
| `tN2kDD475` / `tN2kThrusterControlEvents` | `ThrusterControlEvents` (`OptionSet`) | `Propulsion.swift` |
| `tN2kDD477` / `tN2kWindlassMonitoringEvents` | `WindlassMonitoringEvents` (`OptionSet`) | `Windlass.swift` |
| `tN2kDD478` / `tN2kWindlassControlEvents` | `WindlassControlEvents` (`OptionSet`) | `Windlass.swift` |
| `tN2kDD483` / `tN2kWindlassOperatingEvents` | `WindlassOperatingEvents` (`OptionSet`) | `Windlass.swift` |

## Adding a value

When upstream adds a value to an existing enum, add a `static let` with the same raw value, plus a matching `case` in `description`.
