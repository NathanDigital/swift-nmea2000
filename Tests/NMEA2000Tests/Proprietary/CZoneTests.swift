// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

/// What a status decodes as, in the form frames.cpp's `czone` prints it.
private func describe(_ status: CZoneSwitchStatus) -> String {
  let on = (0...7).map { status.isSwitchOn($0) ? "1" : "0" }.joined()
  return "bank=\(status.bankInstance) field=\(status.fieldIdentifier) bits=\(status.switchBits) "
    + "valid=\(status.isSwitchSummary ? 1 : 0) reserved=\(status.reserved) "
    + "mask=\(status.switchMask) on=\(on) raw=\(status.rawData)"
}

@Suite("CZone switch status")
struct CZoneTests {
  @Test func decodesAsUpstreamDoes() throws {
    // upstream-vectors "CZone 65284" and "CZone 65301"
    let cases: [(UInt32, [UInt8], String)] = [
      (
        65284, [0x27, 0x99, 0x05, 0x1e, 0x2b, 0x01, 0x02, 0x03],
        "bank=5 field=30 bits=43 valid=1 reserved=[1, 2, 3] mask=43 on=01101010 "
          + "raw=[39, 153, 5, 30, 43, 1, 2, 3]"
      ),
      (
        65284, [0x27, 0x99, 0x05, 0x1d, 0xff],
        "bank=5 field=29 bits=255 valid=0 reserved=[0, 0, 0] mask=63 on=00000000 "
          + "raw=[39, 153, 5, 29, 255]"
      ),
      (
        65284, [0x27, 0x99, 0x05, 0x1e, 0x01, 0xaa],
        "bank=5 field=30 bits=1 valid=1 reserved=[170, 0, 0] mask=1 on=01000000 "
          + "raw=[39, 153, 5, 30, 1, 170]"
      ),
      (
        65301, [0x27, 0x99, 0x07, 0x1e, 0x3f, 0x00, 0x00, 0x00, 0x11, 0x22],
        "bank=7 field=30 bits=63 valid=1 reserved=[0, 0, 0] mask=63 on=01111110 "
          + "raw=[39, 153, 7, 30, 63, 0, 0, 0]"
      ),
    ]
    for (pgn, data, expected) in cases {
      #expect(describe(try CZoneSwitchStatus(Message(pgn: pgn, data: data))) == expected)
    }
  }

  @Test func rejectsWhatUpstreamRejects() {
    // upstream-vectors "CZone 65284" and "CZone 65301"
    let cases: [(UInt32, [UInt8], MessageDecodingError)] = [
      (65284, [0x27, 0x99, 0x05, 0x1e], .invalidLength(pgn: 65284, count: 4, allowed: 5...223)),
      (
        65284, [0x28, 0x99, 0x05, 0x1e, 0x01],
        .unexpectedProprietaryHeader(pgn: 65284, header: 0x9928, expected: 0x9927)
      ),
      (65301, [0x27, 0x99, 0x07, 0x1d, 0x3f], .unexpectedRecord(pgn: 65301, identifier: 0x1d)),
      (65301, [0x27, 0x99, 0x07, 0x3e, 0x3f], .unexpectedRecord(pgn: 65301, identifier: 0x3e)),
      (
        65285, [0x27, 0x99, 0x05, 0x1e, 0x01],
        .unexpectedPGN(actual: 65285, expected: [65284, 65301])
      ),
    ]
    for (pgn, data, error) in cases {
      #expect(throws: error, "\(pgn) \(data)") {
        _ = try CZoneSwitchStatus(Message(pgn: pgn, data: data))
      }
    }
  }
}
