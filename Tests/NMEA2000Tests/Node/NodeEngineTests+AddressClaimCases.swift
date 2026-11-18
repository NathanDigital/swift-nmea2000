// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import Testing

@testable import NMEA2000

extension NodeEngineTests {
  /// Opening, modes and address claims, from `Tools/UpstreamVectors/frames.cpp`.
  static let addressClaimCases: [NodeCase] = [
    NodeCase(
      name: "open", mode: .node,
      steps: [.until(600)],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]"
      ]),
    NodeCase(
      name: "open retries after a failure", mode: .node, failedOpens: 1,
      steps: [.until(1400)],
      upstream: [
        "t=1200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]"
      ]),
    NodeCase(
      name: "discards frames while opening", mode: .node,
      steps: [
        .until(100), .receive(0x09f8_0117, [1, 2, 3, 4, 5, 6, 7, 8]), .until(200),
        .receive(0x09f8_0117, [1, 2, 3, 4, 5, 6, 7, 8]),
      ],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=200 rx pgn=129025 priority=2 source=23 destination=255 data=[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]",
      ]),
    NodeCase(
      name: "sends only after its address claim", mode: .node,
      steps: [.until(190), sendPosition, .until(449), sendPosition, .until(450), sendPosition],
      upstream: [
        "t=190 send refused",
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=449 send refused",
        "t=450 tx id=0x09f80117 data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
      ]),
    NodeCase(
      name: "keeps its address against a higher NAME", mode: .node,
      steps: [.until(500), .claim(source: 23, name: ownName + 1), sendPosition],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=23 destination=255 data=[0x02, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x09f80117 data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
      ]),
    NodeCase(
      name: "moves on against a lower NAME", mode: .node,
      steps: [
        .until(500), .claim(source: 23, name: ownName - 1), sendPosition, .until(749), sendPosition,
        .until(750), sendPosition,
      ],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eeff18 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=23 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 send refused",
        "t=749 send refused",
        "t=750 tx id=0x09f80118 data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
      ]),
    NodeCase(
      name: "changes device instance against its own NAME while claiming", mode: .node,
      steps: [
        .until(300), .claim(source: 23, name: ownName), .until(549), sendPosition, .until(550),
        sendPosition,
      ],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=300 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x01, 0x82, 0x32, 0xc0]",
        "t=300 rx pgn=60928 priority=6 source=23 destination=255 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=549 send refused",
        "t=550 tx id=0x09f80117 data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
      ]),
    NodeCase(
      name: "moves on against its own NAME after claiming", mode: .node,
      steps: [.until(500), .claim(source: 23, name: ownName)],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eeff18 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=23 destination=255 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
      ]),
    NodeCase(
      name: "ignores claims for other addresses", mode: .node,
      steps: [
        .until(500), .claim(source: 24, name: ownName - 1), .claim(source: 254, name: ownName - 1),
      ],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=24 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=254 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
      ]),
    NodeCase(
      name: "reclaims against a short claim", mode: .node,
      steps: [.until(500), .claim(source: 23, name: ownName - 1, count: 7)],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=23 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32]",
      ]),
    NodeCase(
      name: "wraps from address 251 to 0", mode: .node, address: 251,
      steps: [.until(500), .claim(source: 251, name: ownName - 1)],
      upstream: [
        "t=200 tx id=0x18eefffb data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eeff00 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=251 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
      ]),
    NodeCase(
      name: "gives up when every address is taken", mode: .node,
      steps: [
        .until(500), .lowerClaimsFromOwnAddress(250), .clearEvents,
        .claim(source: 21, name: ownName - 1), .claim(source: 22, name: ownName - 1), .until(800),
        sendPosition,
      ],
      upstream: [
        "t=500 tx id=0x18eeff16 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=21 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eefffe data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=22 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=800 send refused",
      ]),
    NodeCase(
      name: "gives up from address 0 at 251", mode: .node, address: 0,
      steps: [
        .until(500), .lowerClaimsFromOwnAddress(250), .clearEvents,
        .claim(source: 250, name: ownName - 1), .claim(source: 251, name: ownName - 1),
      ],
      upstream: [
        "t=500 tx id=0x18eefffb data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=250 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 tx id=0x18eefffe data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 rx pgn=60928 priority=6 source=251 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
      ]),
    NodeCase(
      name: "sends from address 251", mode: .node, address: 251,
      steps: [.until(450), sendPosition],
      upstream: [
        "t=200 tx id=0x18eefffb data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=450 tx id=0x09f801fb data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
      ]),
    NodeCase(
      name: "starts from address 14 without one", mode: .node, address: 254,
      steps: [.until(300)],
      upstream: [
        "t=200 tx id=0x18eeff0e data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]"
      ]),
    NodeCase(
      name: "listen and node mode claims", mode: .node,
      steps: [.until(300)],
      upstream: [
        "t=200 tx id=0x18eeff17 data=[0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]"
      ]),
    NodeCase(
      name: "listen only mode stays quiet", mode: .listenOnly,
      steps: [.until(500), .claim(source: 23, name: ownName - 1), sendPosition],
      upstream: [
        "t=500 rx pgn=60928 priority=6 source=23 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
        "t=500 send refused",
      ]),
    NodeCase(
      name: "send only mode doesn't claim", mode: .listenAndSend,
      steps: [.until(200), sendPosition, .claim(source: 23, name: ownName - 1)],
      upstream: [
        "t=200 tx id=0x09f80117 data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
        "t=200 rx pgn=60928 priority=6 source=23 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
      ]),
    NodeCase(
      name: "listen and send mode doesn't claim", mode: .listenAndSend,
      steps: [.until(200), sendPosition, .claim(source: 23, name: ownName - 1)],
      upstream: [
        "t=200 tx id=0x09f80117 data=[0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]",
        "t=200 rx pgn=60928 priority=6 source=23 destination=255 data=[0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]",
      ]),
  ]
}
