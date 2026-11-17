# Proprietary PGNs: upstream → Swift mapping

Upstream keeps manufacturer-specific PGNs out of `N2kMessages` in their own files. This port keeps them in `Sources/NMEA2000/Proprietary/`, apart from the standard PGNs, and tests them against upstream's encoders and parsers in `Tools/UpstreamVectors/frames.cpp` (`scripts/upstream-vectors Maretron CZone`).

| Upstream | Swift |
|---|---|
| `SetN2kMaretronPGN130823` / `ParseN2kMaretronPGN130823` (`…TempHR`) | `MaretronTemperatureHighRange` |
| `SetN2kMaretronPGN65286` / `ParseN2kMaretronPGN65286` (`…FluidFR`) | `MaretronFluidFlowRate` |
| `SetN2kMaretronPGN65287` / `ParseN2kMaretronPGN65287` (`…TripVolume`) | `MaretronTripVolume` |
| `ParseN2kPGN65284CZoneSwitchStatus`, `ParseN2kPGN65301CZoneSwitchStatus`, `tN2kCZoneSwitchStatus` | `CZoneSwitchStatus(_:)`, decode only, as upstream |
| `N2kCZoneIsSwitchOn`, `N2kCZoneSwitchMask` | `CZoneSwitchStatus.isSwitchOn(_:)`, `.switchMask` |

## Kept upstream behaviour

- Maretron messages start with the header `0x9889`; decoding a message without it throws, as upstream's parsers return `false`. Flow rate and trip volume keep upstream's units, litres per hour and litres.
- CZone messages start with the header `0x9927` and need at least five bytes. PGN 65301 must hold the switch summary (field `0x1e`); PGN 65284 may hold any field, and only a switch summary reports switches as on. The raw payload keeps its first eight bytes.
