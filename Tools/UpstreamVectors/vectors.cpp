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
