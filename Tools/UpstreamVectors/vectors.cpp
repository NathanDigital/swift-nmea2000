// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
//
// Test-vector harness: builds messages with upstream's own SetN2kPGN…
// functions and prints their header and payload bytes, so the Swift tests can
// compare against what upstream actually puts on the wire.
//
// Run it with scripts/upstream-vectors. Add a case when porting a PGN; give it
// a name that starts with "PGN<number>" so it can be filtered.

#include <cmath>
#include <cstdio>
#include <cstring>
#include <functional>
#include <vector>

#include "N2kMessages.h"

namespace {

struct Case {
  const char *name;
  std::function<void(tN2kMsg &)> build;
};

// Field helpers. Names match the vectors in MessageWriterTests.swift.
#define FIELD(name, body) {"Field " name, [](tN2kMsg &m) { m.SetPGN(1); body; }}

const std::vector<Case> cases = {
  FIELD("Int8 scaled", m.Add1ByteDouble(1.0, 0.01)),
  FIELD("Int8 below range", m.Add1ByteDouble(-129, 1)),
  FIELD("UInt8 negative", m.Add1ByteUDouble(-1, 1)),
  FIELD("Int16 scaled", m.Add2ByteDouble(-1.5, 0.001)),
  FIELD("Int16 rounds -0.5 down", m.Add2ByteDouble(-0.5, 1)),
  FIELD("Int16 rounds 2.5 away from zero", m.Add2ByteDouble(2.5, 1)),
  FIELD("Int16 above range", m.Add2ByteDouble(32766, 1)),
  FIELD("Int16 NaN", m.Add2ByteDouble(NAN, 1)),
  FIELD("UInt16 scaled", m.Add2ByteUDouble(3.14159, 1e-4)),
  FIELD("Int24 scaled negative", m.Add3ByteDouble(-0.01, 0.01)),
  FIELD("Int24 not available", m.Add3ByteDouble(N2kDoubleNA, 1)),
  FIELD("UInt24 above range", m.Add3ByteUDouble(16777214, 1)),
  FIELD("Int32 latitude", m.Add4ByteDouble(60.1234567, 1e-7)),
  FIELD("Int32 above range", m.Add4ByteDouble(3e9, 1)),
  FIELD("UInt32 negative", m.Add4ByteUDouble(-1, 1)),
  FIELD("Int64 latitude", m.Add8ByteDouble(60.1234567, 1e-16)),
  FIELD("Int64 truncates negative", m.Add8ByteDouble(-2.9, 1)),
  FIELD("Int64 not available", m.Add8ByteDouble(N2kDoubleNA, 1)),
  FIELD("Float32", m.AddFloat(1.5)),
  FIELD("Float32 not available", m.AddFloat(N2kFloatNA)),
  FIELD("Fixed string padded", m.AddStr("ABC", 5)),
  FIELD("AIS string", m.AddAISStr("abc~\xc3\xa9", 8)),
  FIELD("Variable string empty", m.AddVarStr("")),
  FIELD("Variable string ASCII truncated",
        m.AddVarStr("Hi", 1, tN2kMsg::vss_SupportUnicode, tN2kMsg::vsl_UseBytes)),
  FIELD("Variable string UCS-2", m.AddVarStr("\xc3\xa9")),
  FIELD("Variable string UCS-2 three-byte UTF-8", m.AddVarStr("\xe2\x82\xac")),
  FIELD("Variable string UCS-2 outside BMP", m.AddVarStr("a\xf0\x9f\x98\x80")),
  FIELD("Variable string UCS-2 two-byte UTF-8 above U+03FF", m.AddVarStr("\xd0\x96")),
  FIELD("Variable string UCS-2 three-byte UTF-8 above U+7FFF", m.AddVarStr("\xe8\xaa\x9e")),
  FIELD("Variable string forced ASCII mixed scripts",
        m.AddVarStr("\xd0\x96" "a" "\xe8\xaa\x9e" "b" "\xf0\x9f\x98\x80" "c", 5000,
                    tN2kMsg::vss_ForceASCII)),
  {"Field AIS string at capacity", [](tN2kMsg &m) {
     m.SetPGN(1);
     for (int i = 0; i < 221; i++) m.AddByte(0);
     m.AddAISStr("ABCD", 5);
   }},
  FIELD("Variable string forced ASCII",
        m.AddVarStr("\xc3\xa9" "a", 5000, tN2kMsg::vss_ForceASCII)),
  FIELD("Variable string UCS-2 byte limit",
        m.AddVarStr("\xc3\xa9\xc3\xa9", 4, tN2kMsg::vss_SupportUnicode, tN2kMsg::vsl_UseBytes)),
  FIELD("Variable string UCS-2 character limit",
        m.AddVarStr("\xc3\xa9\xc3\xa9\xc3\xa9", 2, tN2kMsg::vss_SupportUnicode,
                    tN2kMsg::vsl_UseCharacters)),

  {"PGN129025 position",
   [](tN2kMsg &m) { SetN2kPGN129025(m, 60.1234567, -151.2093); }},
  {"PGN129025 not available",
   [](tN2kMsg &m) { SetN2kPGN129025(m, N2kDoubleNA, N2kDoubleNA); }},
  {"PGN126992 typical",
   [](tN2kMsg &m) { SetN2kPGN126992(m, 1, 20000, 43200.5, N2ktimes_GPS); }},
  {"PGN126992 not available",
   [](tN2kMsg &m) {
     SetN2kPGN126992(m, 0xff, 0xffff, N2kDoubleNA, N2ktimes_LocalCrystalClock);
   }},
  {"PGN127250 typical",
   [](tN2kMsg &m) { SetN2kPGN127250(m, 2, 1.5, -0.01, 0.12, N2khr_magnetic); }},
  {"PGN127250 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127250(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2khr_Unavailable);
   }},
  {"PGN127251 typical",
   [](tN2kMsg &m) { SetN2kPGN127251(m, 3, -0.02); }},
  {"PGN127251 not available",
   [](tN2kMsg &m) { SetN2kPGN127251(m, 0xff, N2kDoubleNA); }},
  {"PGN127252 typical",
   [](tN2kMsg &m) { SetN2kPGN127252(m, 4, -1.25, 0.5, N2kDD374_FactoryDefault); }},
  {"PGN127252 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127252(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDD374_DataNotAvailable);
   }},
  {"PGN127257 typical",
   [](tN2kMsg &m) { SetN2kPGN127257(m, 5, 1.0, -0.1, 0.2); }},
  {"PGN127257 not available",
   [](tN2kMsg &m) { SetN2kPGN127257(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA); }},
  {"PGN127258 typical",
   [](tN2kMsg &m) { SetN2kPGN127258(m, 6, N2kmagvar_WMM2020, 19000, -0.05); }},
  {"PGN127258 not available",
   [](tN2kMsg &m) { SetN2kPGN127258(m, 0xff, N2kmagvar_Manual, 0xffff, N2kDoubleNA); }},
  {"PGN128259 typical",
   [](tN2kMsg &m) { SetN2kPGN128259(m, 7, 3.5, 3.62, N2kSWRT_Paddle_wheel); }},
  {"PGN128259 not available",
   [](tN2kMsg &m) {
     SetN2kPGN128259(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kSWRT_Electro_magnetic);
   }},
  {"PGN128267 typical",
   [](tN2kMsg &m) { SetN2kPGN128267(m, 8, 12.34, -0.5, 100); }},
  {"PGN128267 not available",
   [](tN2kMsg &m) { SetN2kPGN128267(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA); }},
  {"PGN128275 typical",
   [](tN2kMsg &m) { SetN2kPGN128275(m, 19000, 3600.25, 123456, 789); }},
  {"PGN128275 not available",
   [](tN2kMsg &m) { SetN2kPGN128275(m, 0xffff, N2kDoubleNA, 0xffffffff, 0xffffffff); }},
  {"PGN129026 typical",
   [](tN2kMsg &m) { SetN2kPGN129026(m, 9, N2khr_true, 1.234, 5.67); }},
  {"PGN129026 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129026(m, 0xff, N2khr_Unavailable, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN129029 one reference station",
   [](tN2kMsg &m) {
     SetN2kPGN129029(m, 10, 19000, 43200.5, 60.1234567, -151.2093, 12.5, N2kGNSSt_GPSSBASWAAS, N2kGNSSm_DGNSS, 9, 0.8, 1.6, 18.2, 1, N2kGNSSt_GPS, 42, 3.5);
   }},
  {"PGN129029 no reference stations",
   [](tN2kMsg &m) {
     SetN2kPGN129029(m, 10, 19000, 43200.5, 60.1234567, -151.2093, 12.5, N2kGNSSt_GPSSBASWAAS, N2kGNSSm_DGNSS, 9, 0.8, 1.6, 18.2, 0, N2kGNSSt_GPS, 42, 3.5);
   }},
  {"PGN129029 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129029(m, 0xff, 0xffff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kGNSSt_GPS, N2kGNSSm_Unavailable, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, 0xff, N2kGNSSt_GPS, 0, N2kDoubleNA);
   }},
  {"PGN129033 typical",
   [](tN2kMsg &m) { SetN2kPGN129033(m, 19000, 3600, -120); }},
  {"PGN129033 not available",
   [](tN2kMsg &m) { SetN2kPGN129033(m, 0xffff, N2kDoubleNA, 0x7fff); }},
  {"PGN129283 typical",
   [](tN2kMsg &m) { SetN2kPGN129283(m, 11, N2kxtem_Differential, true, -12.34); }},
  {"PGN129283 not available",
   [](tN2kMsg &m) { SetN2kPGN129283(m, 0xff, N2kxtem_Autonomous, false, N2kDoubleNA); }},
  {"PGN129284 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129284(m, 12, 1852.5, N2khr_magnetic, true, false, N2kdct_RhumbLine, 45000.5, 19001, 0.5, 0.6, 100, 101, 60.15, 24.95, -1.25);
   }},
  {"PGN129284 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129284(m, 0xff, N2kDoubleNA, N2khr_true, false, true, N2kdct_GreatCircle, N2kDoubleNA, 0xffff, N2kDoubleNA, N2kDoubleNA, 0xffffffff, 0xffffffff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN129285 two waypoints",
   [](tN2kMsg &m) {
     SetN2kPGN129285(m, 0, 1, 2, N2kdir_forward, "Harbour run", N2kDD002_No);
     AppendN2kPGN129285(m, 10, "Start", 60.15, 24.95);
     AppendN2kPGN129285(m, 11, "K\xc3\xa4ringe", 60.2, 25.0);
   }},
  {"PGN129285 fills the message",
   [](tN2kMsg &m) {
     SetN2kPGN129285(m, 5, 1, 2, N2kdir_reverse, "", N2kDD002_Yes);
     for (int i = 0; i < 20; i++) {
       char name[16];
       snprintf(name, sizeof name, "Waypoint %02d", i);
       AppendN2kPGN129285(m, i, name, 60 + i * 0.01, 25 + i * 0.01);
     }
   }},
  {"PGN129539 typical",
   [](tN2kMsg &m) { SetN2kPGN129539(m, 13, N2kGNSSdm_3D, N2kGNSSdm_Auto, 0.9, 1.1, 0.7); }},
  {"PGN129539 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129539(m, 0xff, N2kGNSSdm_Unavailable, N2kGNSSdm_Error, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN129540 two satellites",
   [](tN2kMsg &m) {
     SetN2kPGN129540(m, 14, N2kDD072_RangeResidualsWereCalculatedAfterPosition);
     tSatelliteInfo s1{5, 0.5, 2.5, 42.25, -1.5, N2kDD124_UsedInSolutionWithoutDifferentialCorrections};
     AppendN2kPGN129540(m, s1);
     tSatelliteInfo s2{0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDD124_Unavailable};
     AppendN2kPGN129540(m, s2);
   }},
  {"PGN129540 more than the limit",
   [](tN2kMsg &m) {
     SetN2kPGN129540(m, 15, N2kDD072_Unavailable);
     for (int i = 0; i < 20; i++) {
       tSatelliteInfo s{(unsigned char)(i + 1), 0.1 * i, 0.2 * i, 30.0 + i, 0.01 * i, N2kDD124_TrackedButNotUsedInSolution};
       AppendN2kPGN129540(m, s);
     }
   }},
  {"PGN130074 two waypoints",
   [](tN2kMsg &m) {
     SetN2kPGN130074(m, 0, 42, 3);
     AppendN2kPGN130074(m, 1, (char *)"Buoy", 60.15, 24.95);
     AppendN2kPGN130074(m, 2, (char *)"", N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN130074 fills the message",
   [](tN2kMsg &m) {
     SetN2kPGN130074(m, 7, 20, 3);
     for (int i = 0; i < 20; i++) {
       char name[16];
       snprintf(name, sizeof name, "Waypoint %02d", i);
       AppendN2kPGN130074(m, i, name, 60 + i * 0.01, 25 + i * 0.01);
     }
   }},
  {"PGN130577 typical",
   [](tN2kMsg &m) {
     SetN2kPGN130577(m, N2kDD025_Estimated, N2khr_true, 16, 1.1, 2.2, 1.3, 2.1, 0.4, 0.3);
   }},
  {"PGN130577 not available",
   [](tN2kMsg &m) {
     SetN2kPGN130577(m, N2kDD025_Unavailable, N2khr_Unavailable, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN126992 unknown time source",
   [](tN2kMsg &m) { SetN2kPGN126992(m, 1, 20000, 43200.5, (tN2kTimeSource)10); }},
  {"PGN129029 Galileo with an old correction",
   [](tN2kMsg &m) {
     SetN2kPGN129029(m, 10, 19000, 43200.5, -33.8688, 151.2093, -5.25, N2kGNSSt_Galileo, N2kGNSSm_RTKFixed, 12, 0.6, 1.1, -22.5, 1, N2kGNSSt_Galileo, 4000, 400.0);
   }},
  {"PGN129283 unknown mode",
   [](tN2kMsg &m) { SetN2kPGN129283(m, 11, (tN2kXTEMode)10, false, 1.5); }},
  {"PGN129285 long names and negative position",
   [](tN2kMsg &m) {
     SetN2kPGN129285(m, 1, 2, 3, N2kdir_error, "Around the archipelago and back again", N2kDD002_Unavailable);
     AppendN2kPGN129285(m, 4, "\xc3\x84ngs\xc3\xb6 northern anchorage, west side", -33.8688, -151.2093);
   }},
  {"PGN129285 size estimate exactly at the limit",
   [](tN2kMsg &m) {
     SetN2kPGN129285(m, 0, 1, 2, N2kdir_forward, "Route 1234", N2kDD002_No);
     for (int i = 1; i <= 9; i++) {
       char name[16];
       snprintf(name, sizeof name, "WP-%05d", i);
       AppendN2kPGN129285(m, i, name, 60.1 + i * 0.001, 24.9 + i * 0.001);
     }
     AppendN2kPGN129285(m, 10, "\xe6\x9d\xb1\xe4\xba\xac\xe6\xb9\xbe", 60.2, 25.0);
   }},
  {"PGN129285 position exactly at the limit",
   [](tN2kMsg &m) {
     SetN2kPGN129285(m, 0, 1, 2, N2kdir_forward, "Boundary route!", N2kDD002_No);
     for (int i = 1; i <= 9; i++) {
       char name[16];
       snprintf(name, sizeof name, "WP-%05d", i);
       AppendN2kPGN129285(m, i, name, 60.1 + i * 0.001, 24.9 + i * 0.001);
     }
     AppendN2kPGN129285(m, 10, "a\xc3\xa9", 60.2, 25.0);
   }},
  {"PGN130074 entry exactly at the limit",
   [](tN2kMsg &m) {
     SetN2kPGN130074(m, 0, 10, 3);
     for (int i = 1; i <= 9; i++) {
       char name[16];
       snprintf(name, sizeof name, "WP-%05d", i);
       AppendN2kPGN130074(m, i, name, 60.1 + i * 0.001, 24.9 + i * 0.001);
     }
     AppendN2kPGN130074(m, 10, (char *)"Twenty-one characters", 60.2, 25.0);
   }},
  {"PGN127233 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127233(m, 1, 0x12345678, ManualOnBoardMOBButtonActivation, 43200.5, PositionReportedByMOBEmitter, 19000, 43210.25, -33.8688, -151.2093, N2khr_magnetic, 2.5, 1.25, 230123456, Low);
   }},
  {"PGN127233 unknown values",
   [](tN2kMsg &m) {
     SetN2kPGN127233(m, 2, 7, (tN2kMOBStatus)5, 0, (tN2kMOBPositionSource)6, 0, 0, 0, 0, N2khr_Unavailable, 0, 0, 0, (tN2kMOBEmitterBatteryStatus)4);
   }},
  {"PGN127233 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127233(m, 0xff, 0xffffffff, MOBNotActive, N2kDoubleNA, PositionEstimatedByVessel, 0xffff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2khr_true, N2kDoubleNA, N2kDoubleNA, 0xffffffff, Good);
   }},
  {"PGN127237 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127237(m, N2kOnOff_On, N2kOnOff_Off, N2kOnOff_Error, N2kOnOff_Unavailable, N2kSM_TrackControl, N2kTM_RadiusControlled, N2khr_magnetic, N2kRDO_MoveToPort, -0.1, 1.2, 1.25, 0.6, 0.2, -250, -0.05, -40, 1.3);
   }},
  {"PGN127237 unknown values",
   [](tN2kMsg &m) {
     SetN2kPGN127237(m, N2kOnOff_Off, N2kOnOff_Unavailable, N2kOnOff_On, N2kOnOff_Error, (tN2kSteeringMode)6, N2kTM_Unavailable, N2khr_error, (tN2kRudderDirectionOrder)6, 0.1, 0, 0, 0, 0, 250, 0.05, 40, 0);
   }},
  {"PGN127237 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127237(m, N2kOnOff_Unavailable, N2kOnOff_Unavailable, N2kOnOff_Unavailable, N2kOnOff_Unavailable, N2kSM_Unavailable, N2kTM_Unavailable, N2khr_Unavailable, N2kRDO_Unavailable, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN127245 typical",
   [](tN2kMsg &m) { SetN2kPGN127245(m, -0.1, 2, N2kRDO_MoveToStarboard, 0.25); }},
  {"PGN127245 unknown direction",
   [](tN2kMsg &m) { SetN2kPGN127245(m, 0.1, 0, (tN2kRudderDirectionOrder)6, -0.25); }},
  {"PGN127245 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127245(m, N2kDoubleNA, 0xff, N2kRDO_Unavailable, N2kDoubleNA);
   }},
  {"PGN128000 typical",
   [](tN2kMsg &m) { SetN2kPGN128000(m, 3, -0.05); }},
  {"PGN128000 not available",
   [](tN2kMsg &m) { SetN2kPGN128000(m, 0xff, N2kDoubleNA); }},
  {"PGN128776 typical",
   [](tN2kMsg &m) {
     tN2kWindlassControlEvents ev;
     ev.SetEvents(0x01);
     SetN2kPGN128776(m, 4, 1, N2kDD484_Up, 75, N2kDD488_ProportionalSpeed, N2kDD002_Yes, N2kDD002_Yes, N2kDD002_Error, N2kDD002_Unavailable, N2kDD002_No, 1.25, ev);
   }},
  {"PGN128776 other values",
   [](tN2kMsg &m) {
     tN2kWindlassControlEvents ev;
     SetN2kPGN128776(m, 5, 2, N2kDD484_Reserved, 0, N2kDD488_DataNotAvailable, N2kDD002_Unavailable, N2kDD002_Error, N2kDD002_Unavailable, N2kDD002_Yes, N2kDD002_Error, 0.5, ev);
   }},
  {"PGN128776 not available",
   [](tN2kMsg &m) {
     tN2kWindlassControlEvents ev;
     SetN2kPGN128776(m, 0xff, 0xff, N2kDD484_Off, 0xff, N2kDD488_SingleSpeed, N2kDD002_No, N2kDD002_No, N2kDD002_No, N2kDD002_No, N2kDD002_No, N2kDoubleNA, ev);
   }},
  {"PGN128777 typical",
   [](tN2kMsg &m) {
     tN2kWindlassOperatingEvents ev;
     ev.SetEvents(0x11);
     SetN2kPGN128777(m, 6, 1, 45.6, 0.35, N2kDD480_RetrievalOccurring, N2kDD481_RopePresentlyDetected, N2kDD482_FullyDocked, ev);
   }},
  {"PGN128777 other values",
   [](tN2kMsg &m) {
     tN2kWindlassOperatingEvents ev;
     ev.SetEvents(0x1f);
     SetN2kPGN128777(m, 7, 2, 0, 0, N2kDD480_Unavailable, N2kDD481_Unavailable, N2kDD482_Error, ev);
   }},
  {"PGN128777 not available",
   [](tN2kMsg &m) {
     tN2kWindlassOperatingEvents ev;
     SetN2kPGN128777(m, 0xff, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDD480_WindlassStopped, N2kDD481_ChainPresentlyDetected, N2kDD482_DataNotAvailable, ev);
   }},
  {"PGN128778 typical",
   [](tN2kMsg &m) {
     tN2kWindlassMonitoringEvents ev;
     ev.SetEvents(0x05);
     SetN2kPGN128778(m, 8, 1, 3600, 12.6, 85, ev);
   }},
  {"PGN128778 other values",
   [](tN2kMsg &m) {
     tN2kWindlassMonitoringEvents ev;
     ev.SetEvents(0x06);
     SetN2kPGN128778(m, 9, 2, 60, 0.2, 1, ev);
   }},
  {"PGN128778 not available",
   [](tN2kMsg &m) {
     tN2kWindlassMonitoringEvents ev;
     SetN2kPGN128778(m, 0xff, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, ev);
   }},
  {"PGN127237 alternating limit flags",
   [](tN2kMsg &m) {
     SetN2kPGN127237(m, N2kOnOff_Off, N2kOnOff_On, N2kOnOff_Off, N2kOnOff_On, N2kSM_MainSteering, N2kTM_RudderLimitControlled, N2khr_true, N2kRDO_NoDirectionOrder, 0, 0, 0, 0, 0, 0, 0, 0, 0);
   }},
  {"PGN128259 unavailable sensor type",
   [](tN2kMsg &m) { SetN2kPGN128259(m, 7, 3.5, N2kDoubleNA, N2kSWRT_Unavailable); }},
  {"PGN128259 sensor error",
   [](tN2kMsg &m) { SetN2kPGN128259(m, 7, N2kDoubleNA, 3.62, N2kSWRT_Error); }},
  {"PGN129284 bearing reference unavailable",
   [](tN2kMsg &m) {
     SetN2kPGN129284(m, 12, 1852.5, N2khr_Unavailable, false, false, N2kdct_GreatCircle, N2kDoubleNA, 0xffff, 0.5, 0.6, 100, 101, 60.15, 24.95, N2kDoubleNA);
   }},
  {"PGN129284 bearing reference error",
   [](tN2kMsg &m) {
     SetN2kPGN129284(m, 12, 1852.5, N2khr_error, true, true, N2kdct_RhumbLine, N2kDoubleNA, 0xffff, 0.5, 0.6, 100, 101, 60.15, 24.95, N2kDoubleNA);
   }},
  {"PGN126992 defaults",
   [](tN2kMsg &m) { SetN2kPGN126992(m, 1, 20000, 43200.5); }},
  {"PGN127250 defaults",
   [](tN2kMsg &m) { SetN2kMagneticHeading(m, 2, 1.5); }},
  {"PGN127252 defaults",
   [](tN2kMsg &m) { SetN2kHeave(m, 4, -1.25); }},
  {"PGN128259 defaults",
   [](tN2kMsg &m) { SetN2kBoatSpeed(m, 7, 3.5); }},
  {"PGN128267 defaults",
   [](tN2kMsg &m) { SetN2kWaterDepth(m, 8, 12.34, -0.5); }},
  {"PGN129029 defaults",
   [](tN2kMsg &m) {
     SetN2kGNSS(m, 10, 19000, 43200.5, 60.1234567, -151.2093, 12.5, N2kGNSSt_GPS, N2kGNSSm_GNSSfix, 9, 0.8);
   }},
  {"PGN129285 defaults",
   [](tN2kMsg &m) { SetN2kPGN129285(m, 0, 1, 2, N2kdir_forward, "Harbour run"); }},
  {"PGN129540 defaults",
   [](tN2kMsg &m) { SetN2kPGN129540(m); }},
  {"PGN130074 defaults",
   [](tN2kMsg &m) { SetN2kPGN130074(m, 0, 42, 3); }},
  {"PGN127245 defaults",
   [](tN2kMsg &m) { SetN2kRudder(m, 0.1); }},
};

void print(const Case &c) {
  tN2kMsg m;
  c.build(m);
  printf("%s: pgn=%lu priority=%u data=[", c.name, m.PGN, m.Priority);
  for (int i = 0; i < m.DataLen; i++) {
    printf(i == 0 ? "0x%02x" : ", 0x%02x", m.Data[i]);
  }
  printf("]\n");
}

}  // namespace

int main(int argc, char **argv) {
  int printed = 0;
  for (const Case &c : cases) {
    bool selected = argc < 2;
    for (int i = 1; i < argc && !selected; i++) {
      selected = strstr(c.name, argv[i]) != nullptr;
    }
    if (selected) {
      print(c);
      printed++;
    }
  }
  if (printed == 0) {
    fprintf(stderr, "no cases match\n");
    return 1;
  }
  return 0;
}
