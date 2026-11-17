// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

@Suite("Enumerated field types")
struct TypesTests {
  /// Values whose upstream raw value isn't simply their position in the enum.
  @Test(
    "Match upstream raw values",
    arguments: [
      (HeadingReference.unavailable.rawValue, 3),
      (GNSSMethod.error.rawValue, 14),
      (GNSSMethod.unavailable.rawValue, 15),
      (PressureSource.error.rawValue, 254),
      (PressureSource.unavailable.rawValue, 255),
      (HumiditySource.undefined.rawValue, 0xff),
      (WindReference.trueBoat.rawValue, 3),
      (WindReference.error.rawValue, 6),
      (SpeedWaterReferenceType.unavailable.rawValue, 255),
      (RudderDirectionOrder.unavailable.rawValue, 7),
      (AISNavigationStatus.aisSART.rawValue, 14),
      (ConverterOperatingState.hub1.rawValue, 0xfc),
      (ConverterOperatingState.unavailable.rawValue, 0xff),
      (DataMode.unavailable.rawValue, 0xf),
      (PRNUsageStatus.error.rawValue, 14),
      (DelaySource.outOfRange.rawValue, 14),
      (AISAtoNType.lightVessel.rawValue, 31),
      (BinaryStatus.on.rawValue, 1),
      (DCVoltageState.low.rawValue, 2),
      (TemperatureState.high.rawValue, 2),
      (BatteryNominalVoltage.volts36.rawValue, 4),
    ] as [(UInt8, UInt8)])
  func rawValues(actual: UInt8, expected: UInt8) {
    #expect(actual == expected)
  }

  @Test func preservesUnknownValues() {
    let value = TemperatureSource(rawValue: 0x2a)
    #expect(value.rawValue == 0x2a)
    #expect(value != .sea)
    #expect(value.description == "unknown (42)")
  }

  @Test func describesKnownValues() {
    #expect(HeadingReference.true.description == "true")
    #expect(GNSSType.gpsSBASGLONASS.description == "GPS+SBAS/WAAS+GLONASS")
    #expect(BinaryStatus.off.description == "no")
  }

  @Test func flagsUseUpstreamBitPositions() {
    #expect(EngineDiscreteStatus.checkEngine.rawValue == 0x0001)
    #expect(EngineDiscreteStatus.emergencyStopMode.rawValue == 0x8000)
    #expect(EngineWarningStatus.manufacturer1.rawValue == 0x0100)
    #expect(ThrusterMotorEvents.dataNotAvailable.rawValue == 0x80)
    #expect(WindlassOperatingEvents.endOfRodeReached.rawValue == 0x10)
    let flags: EngineDiscreteStatus = [.overTemperature, .lowOilPressure]
    #expect(flags.rawValue == 0x0006)
  }

  @Test func describesFlagsByName() {
    #expect(
      EngineWarningStatus([.warningLevel1, .manufacturer1]).description
        == "[warning level 1, manufacturer defined 1]")
    #expect(
      WindlassControlEvents(rawValue: 0x81).description
        == "[another device is controlling the windlass, unknown (0x80)]")
    #expect(ThrusterMotorEvents([]).description == "[]")
  }
}
