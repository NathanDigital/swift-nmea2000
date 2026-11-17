// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import Testing

@testable import NMEA2000

/// The NAME upstream's node claims with by default.
private let ownName: UInt64 = 0xc032_8200_ffc0_0001

/// A node case from `Tools/UpstreamVectors/frames.cpp`: the steps it takes,
/// and the frames upstream's node sends and the messages it delivers, from
/// `scripts/upstream-vectors Node`.
struct NodeCase: Sendable, CustomTestStringConvertible {
  enum Step: Sendable {
    /// Poll every 10 ms until this many milliseconds into the case.
    case until(UInt64)
    /// Receive a frame.
    case receive(UInt32, [UInt8])
    /// Send a message whose payload counts up from 0.
    case send(pgn: UInt32, count: Int, priority: UInt8)
    /// Receive an address claim with the first `count` bytes of a NAME.
    case claim(source: UInt8, name: UInt64, count: Int = 8)
    /// Receive this many claims with a lower NAME, each from the node's
    /// address at the time.
    case lowerClaimsFromOwnAddress(Int)
    /// Forget the events so far.
    case clearEvents
  }

  enum Event: Hashable, Sendable, CustomStringConvertible {
    case tx(at: UInt64, id: UInt32, data: [UInt8])
    case rx(
      at: UInt64, pgn: UInt32, priority: UInt8, source: UInt8, destination: UInt8, data: [UInt8])

    var description: String {
      switch self {
      case .tx(let time, let id, let data): "t=\(time) tx id=\(hex(id)) data=\(data.map(hex))"
      case .rx(let time, let pgn, let priority, let source, let destination, let data):
        "t=\(time) rx pgn=\(pgn) priority=\(priority) source=\(source) "
          + "destination=\(destination) data=\(data.map(hex))"
      }
    }
  }

  var name: String
  var mode: Node.Mode
  var address: UInt8 = 23
  var failedOpens = 0
  var steps: [Step]
  var events: [Event]

  var testDescription: String { name }
}

private func hex(_ value: some BinaryInteger) -> String {
  "0x" + String(value, radix: 16)
}

/// Drives an engine as the harness drives upstream's node: polling it the
/// way `ParseMessages` does, and opening the transport when it asks.
struct EngineDriver {
  var engine: NodeEngine
  var failedOpens: Int
  var now: UInt64 = 0
  var events: [NodeCase.Event] = []

  init(mode: Node.Mode, address: UInt8, failedOpens: Int = 0) {
    engine = NodeEngine(
      mode: mode, address: address, name: .default, framer: MessageFramer(),
      assembler: MessageAssembler())
    self.failedOpens = failedOpens
  }

  mutating func poll() {
    if engine.shouldOpenTransport(at: now) {
      if failedOpens > 0 {
        failedOpens -= 1
        engine.transportFailedToOpen(at: now)
      } else {
        engine.transportOpened(at: now)
      }
    }
    record(engine.poll(at: now))
  }

  mutating func until(_ time: UInt64) {
    while now < time {
      now += min(10, time - now)
      poll()
    }
  }

  mutating func receive(_ frame: CANFrame) {
    poll()
    let (frames, message) = engine.receive(frame, at: now)
    record(frames)
    if let message {
      events.append(
        .rx(
          at: now, pgn: message.pgn, priority: message.priority, source: message.source,
          destination: message.destination, data: message.data))
    }
  }

  /// Sends a message, returning why the engine refused it, if it did.
  @discardableResult
  mutating func send(_ message: Message) -> NodeError? {
    poll()
    do {
      record(try engine.send(message, at: now))
      return nil
    } catch {
      return error
    }
  }

  mutating func claim(from source: UInt8, name: UInt64, count: Int = 8) {
    let bytes = (0..<count).map { UInt8(truncatingIfNeeded: name >> (8 * $0)) }
    receive(CANFrame(id: 0x18ee_ff00 | UInt32(source), data: bytes))
  }

  mutating func run(_ step: NodeCase.Step) {
    switch step {
    case .until(let time): until(time)
    case .receive(let id, let data): receive(CANFrame(id: id, data: data))
    case .send(let pgn, let count, let priority):
      send(Message(pgn: pgn, priority: priority, data: (0..<count).map(UInt8.init)))
    case .claim(let source, let name, let count): claim(from: source, name: name, count: count)
    case .lowerClaimsFromOwnAddress(let count):
      for _ in 0..<count { claim(from: engine.address, name: ownName - 1) }
    case .clearEvents: events = []
    }
  }

  private mutating func record(_ frames: [CANFrame]) {
    events += frames.map { .tx(at: now, id: $0.id, data: $0.data) }
  }
}

private let claim17: [UInt8] = [0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]
private let lower: [UInt8] = [0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]
private let position: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
private let sendPosition = NodeCase.Step.send(pgn: 129025, count: 8, priority: 2)

private func claimed(at time: UInt64, from source: UInt8) -> NodeCase.Event {
  .tx(at: time, id: 0x18ee_ff00 | UInt32(source), data: claim17)
}

private func claimReceived(
  at time: UInt64, from source: UInt8, data: [UInt8] = lower
) -> NodeCase.Event {
  .rx(at: time, pgn: 60928, priority: 6, source: source, destination: 255, data: data)
}

@Suite("Node engine")
struct NodeEngineTests {
  static let cases: [NodeCase] = [
    NodeCase(
      name: "open", mode: .node, steps: [.until(600)],
      events: [claimed(at: 200, from: 23)]),
    NodeCase(
      name: "open retries after a failure", mode: .node, failedOpens: 1, steps: [.until(1400)],
      events: [claimed(at: 1200, from: 23)]),
    NodeCase(
      name: "discards frames while opening", mode: .node,
      steps: [
        .until(100), .receive(0x09f8_0117, [1, 2, 3, 4, 5, 6, 7, 8]), .until(200),
        .receive(0x09f8_0117, [1, 2, 3, 4, 5, 6, 7, 8]),
      ],
      events: [
        claimed(at: 200, from: 23),
        .rx(
          at: 200, pgn: 129025, priority: 2, source: 23, destination: 255,
          data: [1, 2, 3, 4, 5, 6, 7, 8]),
      ]),
    NodeCase(
      name: "sends only after its address claim", mode: .node,
      steps: [.until(190), sendPosition, .until(449), sendPosition, .until(450), sendPosition],
      events: [
        claimed(at: 200, from: 23), .tx(at: 450, id: 0x09f8_0117, data: position),
      ]),
    NodeCase(
      name: "keeps its address against a higher NAME", mode: .node,
      steps: [.until(500), .claim(source: 23, name: ownName + 1), sendPosition],
      events: [
        claimed(at: 200, from: 23), claimed(at: 500, from: 23),
        claimReceived(
          at: 500, from: 23, data: [0x02, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]),
        .tx(at: 500, id: 0x09f8_0117, data: position),
      ]),
    NodeCase(
      name: "moves on against a lower NAME", mode: .node,
      steps: [
        .until(500), .claim(source: 23, name: ownName - 1), sendPosition, .until(749),
        sendPosition, .until(750), sendPosition,
      ],
      events: [
        claimed(at: 200, from: 23), claimed(at: 500, from: 24), claimReceived(at: 500, from: 23),
        .tx(at: 750, id: 0x09f8_0118, data: position),
      ]),
    NodeCase(
      name: "changes device instance against its own NAME while claiming", mode: .node,
      steps: [
        .until(300), .claim(source: 23, name: ownName), .until(549), sendPosition, .until(550),
        sendPosition,
      ],
      events: [
        claimed(at: 200, from: 23),
        .tx(at: 300, id: 0x18ee_ff17, data: [0x01, 0x00, 0xc0, 0xff, 0x01, 0x82, 0x32, 0xc0]),
        claimReceived(at: 300, from: 23, data: claim17),
        .tx(at: 550, id: 0x09f8_0117, data: position),
      ]),
    NodeCase(
      name: "moves on against its own NAME after claiming", mode: .node,
      steps: [.until(500), .claim(source: 23, name: ownName)],
      events: [
        claimed(at: 200, from: 23), claimed(at: 500, from: 24),
        claimReceived(at: 500, from: 23, data: claim17),
      ]),
    NodeCase(
      name: "ignores claims for other addresses", mode: .node,
      steps: [
        .until(500), .claim(source: 24, name: ownName - 1), .claim(source: 254, name: ownName - 1),
      ],
      events: [
        claimed(at: 200, from: 23), claimReceived(at: 500, from: 24),
        claimReceived(at: 500, from: 254),
      ]),
    NodeCase(
      name: "reclaims against a short claim", mode: .node,
      steps: [.until(500), .claim(source: 23, name: ownName - 1, count: 7)],
      events: [
        claimed(at: 200, from: 23), claimed(at: 500, from: 23),
        claimReceived(at: 500, from: 23, data: Array(lower.prefix(7))),
      ]),
    NodeCase(
      name: "wraps from address 251 to 0", mode: .node, address: 251,
      steps: [.until(500), .claim(source: 251, name: ownName - 1)],
      events: [
        claimed(at: 200, from: 251), claimed(at: 500, from: 0), claimReceived(at: 500, from: 251),
      ]),
    NodeCase(
      name: "gives up when every address is taken", mode: .node,
      steps: [
        .until(500), .lowerClaimsFromOwnAddress(250), .clearEvents,
        .claim(source: 21, name: ownName - 1), .claim(source: 22, name: ownName - 1),
        .until(800), sendPosition,
      ],
      events: [
        claimed(at: 500, from: 22), claimReceived(at: 500, from: 21),
        claimed(at: 500, from: 254), claimReceived(at: 500, from: 22),
      ]),
    NodeCase(
      name: "gives up from address 0 at 251", mode: .node, address: 0,
      steps: [
        .until(500), .lowerClaimsFromOwnAddress(250), .clearEvents,
        .claim(source: 250, name: ownName - 1), .claim(source: 251, name: ownName - 1),
      ],
      events: [
        claimed(at: 500, from: 251), claimReceived(at: 500, from: 250),
        claimed(at: 500, from: 254), claimReceived(at: 500, from: 251),
      ]),
    NodeCase(
      name: "sends from address 251", mode: .node, address: 251,
      steps: [.until(450), sendPosition],
      events: [
        claimed(at: 200, from: 251), .tx(at: 450, id: 0x09f8_01fb, data: position),
      ]),
    NodeCase(
      name: "starts from address 14 without one", mode: .node, address: 254,
      steps: [.until(300)],
      events: [claimed(at: 200, from: 14)]),
    NodeCase(
      name: "listen only mode stays quiet", mode: .listenOnly,
      steps: [.until(500), .claim(source: 23, name: ownName - 1), sendPosition],
      events: [claimReceived(at: 500, from: 23)]),
    NodeCase(
      name: "listen and send mode doesn't claim", mode: .listenAndSend,
      steps: [.until(200), sendPosition, .claim(source: 23, name: ownName - 1)],
      events: [
        .tx(at: 200, id: 0x09f8_0117, data: position), claimReceived(at: 200, from: 23),
      ]),
  ]

  @Test("Behaves as upstream's node", arguments: cases)
  func behavesAsUpstream(_ testCase: NodeCase) {
    var driver = EngineDriver(
      mode: testCase.mode, address: testCase.address, failedOpens: testCase.failedOpens)
    driver.poll()
    for step in testCase.steps { driver.run(step) }
    #expect(driver.events == testCase.events)
  }

  @Test func refusesToSendWithAReason() {
    var driver = EngineDriver(mode: .node, address: 23)
    let message = Message(pgn: 129025, priority: 2, data: position)
    #expect(driver.send(message) == .notOpen)
    driver.until(200)
    #expect(driver.send(message) == .claimingAddress)
    driver.until(450)
    #expect(driver.send(Message(pgn: 0, data: [1])) == .invalidMessage(.invalidPGN(0)))
    #expect(driver.send(message) == nil)

    var listener = EngineDriver(mode: .listenOnly, address: 23)
    listener.until(500)
    #expect(listener.send(message) == .listenOnly)
  }

  @Test func refusesToSendWithoutAnAddress() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    driver.run(.lowerClaimsFromOwnAddress(252))
    #expect(driver.engine.address == 254)
    driver.until(800)
    #expect(driver.send(Message(pgn: 129025, data: position)) == .noAddress)
  }

  @Test func sendsItsOwnAddressClaimWhileClaiming() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(300)
    driver.events = []
    let claim = ISOAddressClaim(name: .default).makeMessage()
    #expect(driver.send(claim) == nil)
    #expect(driver.events == [claimed(at: 300, from: 23)])
  }

  @Test func remembersTheNewAddress() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    driver.claim(from: 23, name: ownName - 1)
    #expect(driver.engine.address == 24)
  }

  @Test func remembersTheNewDeviceInstance() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(300)
    driver.claim(from: 23, name: ownName)
    #expect(driver.engine.name.deviceInstance == 1)
  }

  @Test func countsAddressesFromTheLastOneHeld() {
    // Once a claim at 24 succeeds, the node tries every address up to 23
    // before giving up, not up to 22.
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    driver.claim(from: 23, name: ownName - 1)
    driver.until(800)
    driver.run(.lowerClaimsFromOwnAddress(251))
    #expect(driver.engine.address == 23)
    driver.claim(from: 23, name: ownName - 1)
    #expect(driver.engine.address == 254)
  }

  @Test func reportsItsNextDeadline() {
    var driver = EngineDriver(mode: .node, address: 23, failedOpens: 1)
    #expect(driver.engine.nextDeadline == 0)
    driver.poll()
    #expect(driver.engine.nextDeadline == 1000)
    driver.until(1000)
    #expect(driver.engine.nextDeadline == 1200)
    driver.until(1200)
    #expect(driver.engine.nextDeadline == 1450)
    driver.until(1450)
    #expect(driver.engine.nextDeadline == nil)
  }

  @Test func opensAgainAfterTheTransportCloses() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    driver.engine.transportClosed()
    #expect(driver.engine.nextDeadline == 0)
    driver.events = []
    // The next poll, at 510, opens the transport; the claim follows 200 ms later.
    driver.until(800)
    #expect(driver.events == [claimed(at: 710, from: 23)])
  }
}
