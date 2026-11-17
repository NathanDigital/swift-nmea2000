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
#include "NMEA2000.h"

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
  {"Field variable string UCS-2 with two bytes free", [](tN2kMsg &m) {
     m.SetPGN(1);
     for (int i = 0; i < 221; i++) m.AddByte(0);
     m.AddVarStr("\xc3\xa9");
   }},
  {"Field variable string ASCII with two bytes free", [](tN2kMsg &m) {
     m.SetPGN(1);
     for (int i = 0; i < 221; i++) m.AddByte(0);
     m.AddVarStr("Hi");
   }},
  {"Field variable string ASCII with three bytes free", [](tN2kMsg &m) {
     m.SetPGN(1);
     for (int i = 0; i < 220; i++) m.AddByte(0);
     m.AddVarStr("Hi");
   }},
  FIELD("Variable string forced ASCII",
        m.AddVarStr("\xc3\xa9" "a", 5000, tN2kMsg::vss_ForceASCII)),
  FIELD("Variable string UCS-2 byte limit",
        m.AddVarStr("\xc3\xa9\xc3\xa9", 4, tN2kMsg::vss_SupportUnicode, tN2kMsg::vsl_UseBytes)),
  FIELD("Variable string UCS-2 character limit",
        m.AddVarStr("\xc3\xa9\xc3\xa9\xc3\xa9", 2, tN2kMsg::vss_SupportUnicode,
                    tN2kMsg::vsl_UseCharacters)),

  {"PGN60928 typical",
   [](tN2kMsg &m) { SetN2kPGN60928(m, 1, 2046, 130, 25); }},
  {"PGN60928 every field",
   [](tN2kMsg &m) { SetN2kPGN60928(m, 0x12345, 0x2a5, 0x91, 0x5a, 0xb3, 0x0c, 0x5); }},
  {"PGN60928 fields at their limits",
   [](tN2kMsg &m) { SetN2kPGN60928(m, 0xffffffff, 0xffff, 0xff, 0xff, 0xff, 0xff, 0xff); }},
  {"PGN60928 zero",
   [](tN2kMsg &m) { SetN2kPGN60928(m, 0, 0, 0, 0, 0, 0, 0); }},
  {"PGN60928 NAME",
   [](tN2kMsg &m) { SetN2kPGN60928(m, 0x0123456789abcdefULL); }},
  {"PGN59392 typical",
   [](tN2kMsg &m) { SetN2kPGN59392(m, 1, 0xff, 126998); }},
  {"PGN59392 high bits",
   [](tN2kMsg &m) { SetN2kPGN59392(m, 0xf2, 0x81, 0x3ffff); }},
  {"PGN59904 typical",
   [](tN2kMsg &m) { SetN2kPGN59904(m, 0x42, 126996); }},
  {"PGN59904 high bits",
   [](tN2kMsg &m) { SetN2kPGN59904(m, 0xff, 0xfedcba); }},
  {"PGN126464 transmit",
   [](tN2kMsg &m) {
     static const unsigned long pgns[] = {59392, 126996, 0x3ffff, 0};
     SetN2kPGN126464(m, 0x42, N2kpgnl_transmit, pgns);
   }},
  {"PGN126464 receive empty",
   [](tN2kMsg &m) {
     static const unsigned long pgns[] = {0};
     SetN2kPGN126464(m, 0xff, N2kpgnl_receive, pgns);
   }},
  {"PGN126993 typical",
   [](tN2kMsg &m) { SetN2kPGN126993(m, 60000, 3); }},
  {"PGN126993 zero",
   [](tN2kMsg &m) { SetN2kPGN126993(m, 0, 1); }},
  {"PGN126993 widest field",
   [](tN2kMsg &m) { SetN2kPGN126993(m, 65535, 0); }},
  {"PGN126993 over the field",
   [](tN2kMsg &m) { SetN2kPGN126993(m, 65536, 252); }},
  {"PGN126993 at the limit",
   [](tN2kMsg &m) { SetN2kPGN126993(m, 655320, 0xff); }},
  {"PGN126993 over the limit",
   [](tN2kMsg &m) { SetN2kPGN126993(m, 655321, 0xff); }},
  {"PGN126996 typical",
   [](tN2kMsg &m) { SetN2kPGN126996(m, 2101, 666, "Swift Gateway", "1.2.3", "Rev A", "SN-0042", 2, 3); }},
  {"PGN126996 defaults",
   [](tN2kMsg &m) { SetN2kPGN126996(m, 0xffff, 0xffff, "", "", "", ""); }},
  {"PGN126996 long strings",
   [](tN2kMsg &m) {
     SetN2kPGN126996(m, 1, 2, "0123456789abcdef0123456789ABCDEFxyz", "W\xc3\xa4rtsil\xc3\xa4", "v", "s", 0, 0xff);
   }},
  {"PGN126998 typical",
   [](tN2kMsg &m) { SetN2kPGN126998(m, "Kave Oy", "Mast head", "Starboard side"); }},
  {"PGN126998 empty",
   [](tN2kMsg &m) { SetN2kPGN126998(m, "", 0, ""); }},
  {"PGN126998 unicode and long",
   [](tN2kMsg &m) {
     SetN2kPGN126998(m, "0123456789012345678901234567890123456789012345678901234567890123456789XYZ", "B\xc3\xa5t", "a");
   }},
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
  {"PGN128776 defaults",
   [](tN2kMsg &m) { SetN2kPGN128776(m, 4, 1, N2kDD484_Down, 30); }},
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
  {"PGN128777 defaults",
   [](tN2kMsg &m) { SetN2kPGN128777(m, 6, 1, 45.6); }},
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
  {"PGN128778 defaults",
   [](tN2kMsg &m) { SetN2kPGN128778(m, 8, 1, 3600); }},
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
  {"PGN127488 typical",
   [](tN2kMsg &m) { SetN2kPGN127488(m, 1, 2450.25, 150000, -12); }},
  {"PGN127488 not available",
   [](tN2kMsg &m) { SetN2kPGN127488(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kInt8NA); }},
  {"PGN127488 defaults",
   [](tN2kMsg &m) { SetN2kEngineParamRapid(m, 0, 800); }},
  {"PGN127489 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127489(m, 1, 350000, 363.15, 358.15, 14.2, -12.5, 3600000, 120000, 300000, 85, -5, tN2kEngineDiscreteStatus1(0x8421), tN2kEngineDiscreteStatus2(0x00a5));
   }},
  {"PGN127489 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127489(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kInt8NA, N2kInt8NA, tN2kEngineDiscreteStatus1(0), tN2kEngineDiscreteStatus2(0));
   }},
  {"PGN127489 defaults",
   [](tN2kMsg &m) {
     // SetN2kEngineDynamicParam with only the required arguments is ambiguous
     // upstream, so pass its declared defaults explicitly.
     SetN2kPGN127489(m, 0, 300000, 360, 350, 13.8, 10, 7200, N2kDoubleNA, N2kDoubleNA, N2kInt8NA, N2kInt8NA, tN2kEngineDiscreteStatus1(0), tN2kEngineDiscreteStatus2(0));
   }},
  {"PGN127493 typical",
   [](tN2kMsg &m) { SetN2kPGN127493(m, 1, N2kTG_Reverse, 1500000, 353.15, 0x15); }},
  {"PGN127493 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127493(m, 0xff, N2kTG_Unknown, N2kDoubleNA, N2kDoubleNA, 0x0a);
   }},
  {"PGN127493 defaults",
   [](tN2kMsg &m) { SetN2kTransmissionParameters(m, 0, N2kTG_Forward, 1000000, 340); }},
  {"PGN127497 typical",
   [](tN2kMsg &m) { SetN2kPGN127497(m, 1, 125, 15.5, -2.5, 18.25); }},
  {"PGN127497 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127497(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN127497 defaults",
   [](tN2kMsg &m) { SetN2kEngineTripParameters(m, 0, 40, 12.5); }},
  {"PGN127501 four switches",
   [](tN2kMsg &m) {
     SetN2kPGN127501(m, 3, N2kOnOff_On, N2kOnOff_Off, N2kOnOff_Error, N2kOnOff_Unavailable);
   }},
  {"PGN127501 full bank from a packed value",
   [](tN2kMsg &m) { SetN2kPGN127501(m, 4, (tN2kBinaryStatus)0x00e4e4e4e4e4e4e4ULL); }},
  {"PGN127501 no switches",
   [](tN2kMsg &m) {
     tN2kBinaryStatus b;
     N2kResetBinaryStatus(b);
     SetN2kPGN127501(m, 0, b);
   }},
  {"PGN127502 four switches",
   [](tN2kMsg &m) { SetN2kPGN127502(m, 5, (tN2kBinaryStatus)0xffffffffffffff1bULL); }},
  {"PGN127502 full bank from a packed value",
   [](tN2kMsg &m) { SetN2kPGN127502(m, 6, (tN2kBinaryStatus)0x001b1b1b1b1b1b1bULL); }},
  {"PGN127505 typical",
   [](tN2kMsg &m) { SetN2kPGN127505(m, 2, N2kft_BlackWater, 75.5, 120.5); }},
  {"PGN127505 high instance and type",
   [](tN2kMsg &m) { SetN2kPGN127505(m, 0x0e, N2kft_Error, -1.0, 4000); }},
  {"PGN127505 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127505(m, 0x0f, N2kft_Unavailable, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN127506 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127506(m, 1, 2, N2kDCt_WindGenerator, 87, 95, 7200, 0.025, 720000);
   }},
  {"PGN127506 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127506(m, 0xff, 0xff, (tN2kDCType)0xff, 0xff, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN127506 defaults",
   [](tN2kMsg &m) { SetN2kDCStatus(m, 1, 0, N2kDCt_Battery, 50, 100, 3600); }},
  {"PGN127507 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127507(m, 1, 2, N2kCS_Absorption, N2kCM_Secondary, N2kOnOff_On, N2kOnOff_Off, 90);
   }},
  {"PGN127507 high values",
   [](tN2kMsg &m) {
     SetN2kPGN127507(m, 3, 4, N2kCS_Error, N2kCM_Unavailable, N2kOnOff_Error, N2kOnOff_Unavailable, 0);
   }},
  {"PGN127507 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127507(m, 0xff, 0xff, N2kCS_Unavailable, N2kCM_Unavailable, N2kOnOff_Unavailable, N2kOnOff_Unavailable, N2kDoubleNA);
   }},
  {"PGN127507 defaults",
   [](tN2kMsg &m) { SetN2kChargerStatus(m, 0, 1, N2kCS_Bulk); }},
  {"PGN127508 typical",
   [](tN2kMsg &m) { SetN2kPGN127508(m, 1, 12.85, -25.5, 298.15, 7); }},
  {"PGN127508 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127508(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, 0xff);
   }},
  {"PGN127508 defaults",
   [](tN2kMsg &m) { SetN2kDCBatStatus(m, 0, 13.2); }},
  {"PGN127510 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127510(m, 1, 2, N2kOnOff_On, 80, N2kCA_2Stage, N2kCM_Primary, N2kBT_hot, N2kOnOff_Error, N2kOnOff_On, 120);
   }},
  {"PGN127510 high values",
   [](tN2kMsg &m) {
     SetN2kPGN127510(m, 3, 4, N2kOnOff_Unavailable, 252, N2kCA_Error, N2kCM_Echo, N2kBT_Error, N2kOnOff_Unavailable, N2kOnOff_Error, 0);
   }},
  {"PGN127510 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127510(m, 0xff, 0xff, N2kOnOff_Unavailable, 0xff, N2kCA_NotAvailable, N2kCM_Unavailable, N2kBT_NotAvailable, N2kOnOff_Unavailable, N2kOnOff_Unavailable, 0xffff);
   }},
  {"PGN127510 defaults",
   [](tN2kMsg &m) { SetN2kChargerConf(m, 0, 1); }},
  {"PGN127513 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127513(m, 1, N2kDCbt_AGM, N2kDCES_Yes, N2kDCbnv_12v, N2kDCbc_LeadAcid, 720000, -2, 1.25, 95);
   }},
  {"PGN127513 large capacity and high values",
   [](tN2kMsg &m) {
     SetN2kPGN127513(m, 2, (tN2kBatType)9, N2kDCES_Unavailable, N2kDCbnv_48v, N2kDCbc_NiMh, 144000000, 3, 1.504, -10);
   }},
  {"PGN127513 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127513(m, 0xff, N2kDCbt_Flooded, N2kDCES_No, N2kDCbnv_6v, N2kDCbc_LeadAcid, N2kDoubleNA, N2kInt8NA, N2kDoubleNA, N2kInt8NA);
   }},
  {"PGN127750 typical",
   [](tN2kMsg &m) {
     SetN2kPGN127750(m, 1, 2, N2kCICS_Inverting, N2kTS_Warning, N2kOS_OK, N2kDCVS_Warning, N2kRP_High);
   }},
  {"PGN127750 other values",
   [](tN2kMsg &m) {
     SetN2kPGN127750(m, 3, 4, N2kCICS_Hub1, N2kTS_OK, N2kOS_Overload, N2kDCVS_OK, N2kRP_Warning);
   }},
  {"PGN127750 not available",
   [](tN2kMsg &m) {
     SetN2kPGN127750(m, 0xff, 0xff, N2kCICS_NotAvailable, N2kTS_NotAvailable, N2kOS_NotAvailable, N2kDCVS_NotAvailable, N2kRP_NotAvailable);
   }},
  {"PGN127751 typical",
   [](tN2kMsg &m) { SetN2kPGN127751(m, 1, 12.6, 35.25, 9); }},
  {"PGN127751 negative current",
   [](tN2kMsg &m) { SetN2kPGN127751(m, 2, 48.0, -1234.56, 10); }},
  {"PGN127751 not available",
   [](tN2kMsg &m) { SetN2kPGN127751(m, 0xff, N2kDoubleNA, N2kDoubleNA, 0xff); }},
  {"PGN127751 defaults",
   [](tN2kMsg &m) { SetN2kDCVoltageCurrent(m, 0, 13.1); }},
  {"PGN127513 unknown voltage and chemistry",
   [](tN2kMsg &m) {
     SetN2kPGN127513(m, 3, N2kDCbt_Gel, N2kDCES_Error, (tN2kBatNomVolt)9, (tN2kBatChem)12, 360000, 0, 1.4, 100);
   }},
  {"PGN130306 typical",
   [](tN2kMsg &m) { SetN2kPGN130306(m, 1, 7.5, 5.5, N2kWind_Apparent); }},
  {"PGN130306 true over water",
   [](tN2kMsg &m) { SetN2kPGN130306(m, 2, 12.25, 0.25, N2kWind_True_water); }},
  {"PGN130306 not available",
   [](tN2kMsg &m) {
     SetN2kPGN130306(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kWind_Unavailable);
   }},
  {"PGN130310 typical",
   [](tN2kMsg &m) { SetN2kPGN130310(m, 1, 288.15, 293.65, 101325); }},
  {"PGN130310 not available",
   [](tN2kMsg &m) { SetN2kPGN130310(m, 0xff, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA); }},
  {"PGN130310 defaults",
   [](tN2kMsg &m) { SetN2kOutsideEnvironmentalParameters(m, 1, 285.5); }},
  {"PGN130311 typical",
   [](tN2kMsg &m) {
     SetN2kPGN130311(m, 1, N2kts_ShaftSealTemperature, 310.5, N2khs_OutsideHumidity, 65.5, 100800);
   }},
  {"PGN130311 high temperature source code",
   [](tN2kMsg &m) {
     SetN2kPGN130311(m, 2, (tN2kTempSource)0x2a, 250, N2khs_InsideHumidity, -1.0, 99000);
   }},
  {"PGN130311 not available",
   [](tN2kMsg &m) {
     SetN2kPGN130311(m, 0xff, N2kts_SeaTemperature, N2kDoubleNA, N2khs_Undef, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN130311 defaults",
   [](tN2kMsg &m) {
     SetN2kEnvironmentalParameters(m, 1, N2kts_MainCabinTemperature, 294.15);
   }},
  {"PGN130312 typical",
   [](tN2kMsg &m) { SetN2kPGN130312(m, 1, 3, N2kts_FreezerTemperature, 255.15, 253.15); }},
  {"PGN130312 unknown source",
   [](tN2kMsg &m) { SetN2kPGN130312(m, 2, 0xfe, (tN2kTempSource)0xc8, 600, N2kDoubleNA); }},
  {"PGN130312 not available",
   [](tN2kMsg &m) {
     SetN2kPGN130312(m, 0xff, 0xff, (tN2kTempSource)0xff, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN130312 defaults",
   [](tN2kMsg &m) { SetN2kTemperature(m, 1, 0, N2kts_EngineRoomTemperature, 320); }},
  {"PGN130313 typical",
   [](tN2kMsg &m) { SetN2kPGN130313(m, 1, 2, N2khs_InsideHumidity, 55.5, 50); }},
  {"PGN130313 undefined source",
   [](tN2kMsg &m) { SetN2kPGN130313(m, 2, 3, N2khs_Undef, -2.5, N2kDoubleNA); }},
  {"PGN130313 not available",
   [](tN2kMsg &m) {
     SetN2kPGN130313(m, 0xff, 0xff, N2khs_Undef, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN130313 defaults",
   [](tN2kMsg &m) { SetN2kHumidity(m, 1, 0, N2khs_OutsideHumidity, 80); }},
  {"PGN130314 typical",
   [](tN2kMsg &m) { SetN2kPGN130314(m, 1, 2, N2kps_Hydraulic, 2500000.5); }},
  {"PGN130314 negative pressure",
   [](tN2kMsg &m) { SetN2kPGN130314(m, 2, 3, N2kps_Error, -5000); }},
  {"PGN130314 not available",
   [](tN2kMsg &m) { SetN2kPGN130314(m, 0xff, 0xff, N2kps_Unavailable, N2kDoubleNA); }},
  {"PGN130315 typical",
   [](tN2kMsg &m) { SetN2kPGN130315(m, 1, 2, N2kps_Hydraulic, 2500000.5); }},
  {"PGN130315 negative pressure",
   [](tN2kMsg &m) { SetN2kPGN130315(m, 2, 3, N2kps_Error, -5000); }},
  {"PGN130315 not available",
   [](tN2kMsg &m) { SetN2kPGN130315(m, 0xff, 0xff, N2kps_Unavailable, N2kDoubleNA); }},
  {"PGN130316 typical",
   [](tN2kMsg &m) {
     SetN2kPGN130316(m, 1, 4, N2kts_ExhaustGasTemperature, 850.125, 900.5);
   }},
  {"PGN130316 high values",
   [](tN2kMsg &m) { SetN2kPGN130316(m, 2, 0xfe, (tN2kTempSource)0x80, 16000, 6000); }},
  {"PGN130316 not available",
   [](tN2kMsg &m) {
     SetN2kPGN130316(m, 0xff, 0xff, (tN2kTempSource)0xff, N2kDoubleNA, N2kDoubleNA);
   }},
  {"PGN130316 defaults",
   [](tN2kMsg &m) { SetN2kTemperatureExt(m, 1, 0, N2kts_OutsideTemperature, 278.15); }},
  {"PGN130323 typical",
   [](tN2kMsg &m) {
     tN2kMeteorlogicalStationData d;
     d.Mode = N2kaismode_Assigned;
     d.SystemDate = 19000;
     d.SystemTime = 43200.5;
     d.Latitude = -33.8688;
     d.Longitude = -151.2093;
     d.WindSpeed = 8.5;
     d.WindDirection = 3.5;
     d.WindReference = N2kWind_True_North;
     d.WindGusts = 12.25;
     d.AtmosphericPressure = 101300;
     d.OutsideAmbientAirTemperature = 291.15;
     d.SetStationID("SYD-01");
     d.SetStationName("Sydney \xc3\x96" "bservatory");
     SetN2kPGN130323(m, d);
   }},
  {"PGN130323 long names",
   [](tN2kMsg &m) {
     tN2kMeteorlogicalStationData d;
     d.Mode = (tN2kAISMode)9;
     d.WindReference = N2kWind_Error;
     d.SetStationID("ABCDEFGHIJKLMNO");
     d.SetStationName("An extremely long meteorological station name over 50");
     SetN2kPGN130323(m, d);
   }},
  {"PGN130323 defaults",
   [](tN2kMsg &m) {
     tN2kMeteorlogicalStationData d;
     SetN2kPGN130323(m, d);
   }},
  {"PGN130576 typical",
   [](tN2kMsg &m) { SetN2kPGN130576(m, 25, -10); }},
  {"PGN130576 not available",
   [](tN2kMsg &m) { SetN2kPGN130576(m, N2kInt8NA, N2kInt8NA); }},
  {"PGN130323 non-ASCII names at the buffer limit",
   [](tN2kMsg &m) {
     tN2kMeteorlogicalStationData d;
     d.SetStationID("\xc3\x96rebro-\xc3\x96st-7");
     d.SetStationName("V\xc3\xa4" "der\xc3\xb6station p\xc3\xa5 \xc3\x85land, n\xc3\xa4ra Mariehamn hamn och fyr");
     SetN2kPGN130323(m, d);
   }},
  {"PGN129038 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129038(m, 1, N2kaisr_Initial, 230123456, 60.1234567, -24.9876543, true, false, 42, 1.5, 6.25, N2kaischannel_B_VDL_transmission, 1.55, -0.01, N2kaisns_Under_Way_Motoring, 7);
   }},
  {"PGN129038 high field values",
   [](tN2kMsg &m) {
     SetN2kPGN129038(m, 63, N2kaisr_Final, 0xffffffff, -33.8688, 151.2093, false, true, 63, 0, 0, (tN2kAISTransceiverInformation)31, 0, 0.02, (tN2kAISNavStatus)13, 0xfe);
   }},
  {"PGN129038 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129038(m, 3, N2kaisr_First, 0, N2kDoubleNA, N2kDoubleNA, false, false, 60, N2kDoubleNA, N2kDoubleNA, N2kaischannel_A_VDL_reception, N2kDoubleNA, N2kDoubleNA, N2kaisns_AIS_SART, 0xff);
   }},
  {"PGN129039 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129039(m, 18, N2kaisr_Second, 211234567, 54.321, 10.123, true, true, 30, 3.0, 2.5, N2kaischannel_A_VDL_reception, 3.05, N2kaisunit_ClassB_CS, true, false, true, false, N2kaismode_Assigned, false, 9);
   }},
  {"PGN129039 other flags",
   [](tN2kMsg &m) {
     SetN2kPGN129039(m, 63, N2kaisr_Final, 1, -1.5, -2.5, false, false, 63, 0, 0, (tN2kAISTransceiverInformation)31, 0, N2kaisunit_ClassB_SOTDMA, false, true, false, true, N2kaismode_Autonomous, true, 0xff);
   }},
  {"PGN129039 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129039(m, 19, N2kaisr_Initial, 0, N2kDoubleNA, N2kDoubleNA, false, false, 60, N2kDoubleNA, N2kDoubleNA, N2kaischannel_B_VDL_reception, N2kDoubleNA, N2kaisunit_ClassB_SOTDMA, false, false, false, false, N2kaismode_Autonomous, false, 0xff);
   }},
  {"PGN129041 typical",
   [](tN2kMsg &m) {
     tN2kAISAtoNReportData d;
     d.MessageID = 21;
     d.Repeat = N2kaisr_Initial;
     d.UserID = 992761234;
     d.Longitude = 24.9512;
     d.Latitude = 60.1695;
     d.Accuracy = true;
     d.RAIM = false;
     d.Seconds = 15;
     d.Length = 5.5;
     d.Beam = 2.5;
     d.PositionReferenceStarboard = 1.2;
     d.PositionReferenceTrueNorth = 2.75;
     d.AtoNType = N2kAISAtoN_beacon_cardinal_N;
     d.OffPositionIndicator = false;
     d.VirtualAtoNFlag = true;
     d.AssignedModeFlag = false;
     d.GNSSType = N2kGNSSt_GPSGLONASS;
     d.AtoNStatus = 0;
     d.AISTransceiverInformation = N2kaischannel_A_VDL_transmission;
     d.SetAtoNName("Harmaja light");
     SetN2kPGN129041(m, d);
   }},
  {"PGN129041 high field values and long name",
   [](tN2kMsg &m) {
     tN2kAISAtoNReportData d;
     d.MessageID = 63;
     d.Repeat = N2kaisr_Final;
     d.UserID = 1;
     d.Longitude = -151.2093;
     d.Latitude = -33.8688;
     d.Accuracy = false;
     d.RAIM = true;
     d.Seconds = 63;
     d.Length = 6553.0;
     d.Beam = 0;
     d.PositionReferenceStarboard = 0;
     d.PositionReferenceTrueNorth = 0;
     d.AtoNType = N2kAISAtoN_light_vessel_lanby_rigs;
     d.OffPositionIndicator = true;
     d.VirtualAtoNFlag = false;
     d.AssignedModeFlag = true;
     d.GNSSType = N2kGNSSt_Galileo;
     d.AtoNStatus = 165;
     d.AISTransceiverInformation = (tN2kAISTransceiverInformation)31;
     d.SetAtoNName("Very long AtoN name \xc3\xa4" "bove the 34 character limit");
     SetN2kPGN129041(m, d);
   }},
  {"PGN129041 defaults",
   [](tN2kMsg &m) {
     tN2kAISAtoNReportData d;
     SetN2kPGN129041(m, d);
   }},
  {"PGN129794 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129794(m, 5, N2kaisr_Initial, 230123456, 9876543, "oh2abc", "m/s Example Vessel", 70, 188.5, 30.25, 15.5, 140.0, 19001, 50400, 10.75, "Helsinki", N2kaisv_ITU_R_M_1371_3, N2kGNSSt_GPS, N2kaisdte_Ready, N2kaischannel_A_VDL_reception, 11);
   }},
  {"PGN129794 long and non-ASCII text, high field values",
   [](tN2kMsg &m) {
     SetN2kPGN129794(m, 63, N2kaisr_Final, 1, 0, "CALLSIGN9", "N\xc3\xa4me longer than twenty chars", 255, 0, 0, 0, 0, 0, 0, -1.5, "Destination name too long~", (tN2kAISVersion)3, N2kGNSSt_Galileo, N2kaisdte_NotReady, (tN2kAISTransceiverInformation)31, 0xfe);
   }},
  {"PGN129794 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129794(m, 5, N2kaisr_Initial, 0, 0, "", "", 0, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, 0xffff, N2kDoubleNA, N2kDoubleNA, "", N2kaisv_ITU_R_M_1371_1, N2kGNSSt_GPS, N2kaisdte_Ready, N2kaischannel_A_VDL_reception, 0xff);
   }},
  {"PGN129794 defaults",
   [](tN2kMsg &m) {
     SetN2kPGN129794(m, 5, N2kaisr_Initial, 230000001, 0, "AB", "SHIP", 30, 10, 3, 1, 5, 19000, 0, 1, "PORT", N2kaisv_ITU_R_M_1371_1, N2kGNSSt_GPS, N2kaisdte_Ready);
   }},
  {"PGN129802 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129802(m, 14, N2kaisr_Initial, 230123456, N2kaischannel_A_VDL_transmission, "MOB ALERT near buoy 5");
   }},
  {"PGN129802 high field values and non-ASCII text",
   [](tN2kMsg &m) {
     SetN2kPGN129802(m, 63, N2kaisr_Final, 0xffffffff, (tN2kAISTransceiverInformation)31, "Var\xc3\xa5 storm");
   }},
  {"PGN129802 empty text",
   [](tN2kMsg &m) {
     SetN2kPGN129802(m, 14, N2kaisr_Second, 1, N2kaischannel_B_VDL_reception, "");
   }},
  {"PGN129809 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129809(m, 24, N2kaisr_Initial, 230123456, "sailing yacht", N2kaischannel_B_VDL_transmission, 3);
   }},
  {"PGN129809 high field values and long name",
   [](tN2kMsg &m) {
     SetN2kPGN129809(m, 63, N2kaisr_Final, 0xffffffff, "A name far longer than twenty", (tN2kAISTransceiverInformation)31, 0xfe);
   }},
  {"PGN129809 defaults",
   [](tN2kMsg &m) { SetN2kPGN129809(m, 24, N2kaisr_Initial, 230000002, "BOAT"); }},
  {"PGN129810 typical",
   [](tN2kMsg &m) {
     SetN2kPGN129810(m, 24, N2kaisr_Initial, 230123456, 36, "acme01", "oh2xyz", 12.5, 4.25, 2.0, 9.5, 0, N2kaischannel_A_VDL_transmission, 4);
   }},
  {"PGN129810 high field values",
   [](tN2kMsg &m) {
     SetN2kPGN129810(m, 63, N2kaisr_Final, 0xffffffff, 255, "VENDOR12", "C\xc3\xa4LL", 0, 0, 0, 0, 0xffffffff, (tN2kAISTransceiverInformation)31, 0xfe);
   }},
  {"PGN129810 not available",
   [](tN2kMsg &m) {
     SetN2kPGN129810(m, 24, N2kaisr_Initial, 0, 0, "", "", N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, N2kDoubleNA, 0, N2kaischannel_A_VDL_reception, 0xff);
   }},
  {"PGN129810 defaults",
   [](tN2kMsg &m) {
     SetN2kPGN129810(m, 24, N2kaisr_Initial, 230000003, 37, "V", "C", 8, 3, 1, 4, 0);
   }},
  {"PGN129039 unknown unit type without display",
   [](tN2kMsg &m) {
     SetN2kPGN129039(m, 18, N2kaisr_Initial, 2, 1.0, 2.0, false, true, 10, 1.0, 1.0, N2kaischannel_A_VDL_reception, 1.0, (tN2kAISUnit)3, false, false, false, false, N2kaismode_Autonomous, false, 1);
   }},
  {"PGN129039 display without class B CS",
   [](tN2kMsg &m) {
     SetN2kPGN129039(m, 18, N2kaisr_Initial, 3, 1.0, 2.0, true, false, 11, 1.0, 1.0, N2kaischannel_A_VDL_reception, 1.0, N2kaisunit_ClassB_SOTDMA, true, false, false, false, N2kaismode_Autonomous, false, 2);
   }},
  {"PGN129794 unknown DTE code",
   [](tN2kMsg &m) {
     SetN2kPGN129794(m, 5, N2kaisr_Initial, 230000004, 0, "X", "Y", 0, 1, 1, 1, 1, 19000, 0, 1, "Z", N2kaisv_ITU_R_M_1371_1, N2kGNSSt_GPS, (tN2kAISDTE)3, N2kaischannel_A_VDL_reception, 5);
   }},
  {"PGN129802 text over the limit",
   [](tN2kMsg &m) {
     SetN2kPGN129802(m, 14, N2kaisr_Initial, 230123456, N2kaischannel_A_VDL_transmission, "Navigational warning: buoy 7 off station near the fairway entrance, buoy 7 off station near the fairway entrance, buoy 7 off station near the fairway entrance, buoy 7 off station near the fairway entrance, ");
   }},
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
  for (const Case &c : cases) {
    bool selected = argc < 2;
    for (int i = 1; i < argc && !selected; i++) {
      selected = strstr(c.name, argv[i]) != nullptr;
    }
    if (selected) print(c);
  }
  return 0;
}
