// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import Testing

@testable import NMEA2000

@Suite("Node engine")
struct NodeEngineTests {
  static let cases: [NodeCase] =
    addressClaimCases + transportProtocolCases + networkManagementCases + groupFunctionCases
    + deviceListCases + multipleDeviceCases

  @Test("Behaves as upstream's node", arguments: cases)
  func behavesAsUpstream(_ testCase: NodeCase) {
    var driver = EngineDriver(
      mode: testCase.mode, address: testCase.address, failedOpens: testCase.failedOpens,
      deviceCount: testCase.deviceCount, transmitPGNs: testCase.transmitPGNs,
      receivePGNs: testCase.receivePGNs, configuration: testCase.configuration,
      isoRequestHandler: testCase.isoRequestHandler, discoversDevices: testCase.discoversDevices)
    driver.engine.groupFunctionHandlers = testCase.groupFunctionHandlers
    driver.poll()
    for step in testCase.steps { driver.run(step) }
    driver.dumpDevices()
    #expect(driver.events.map(\.description) == testCase.upstream)
  }

  static let productStringFields: [(UInt8, String)] = [
    (4, ProductInformation.default.softwareVersion),
    (5, ProductInformation.default.modelVersion),
    (6, ProductInformation.default.modelSerialCode),
  ]

  @Test(arguments: productStringFields)
  func matchesProductFieldsAgainstTheirOwnValues(field: UInt8, value: String) throws {
    // Deliberate divergence: upstream compares these fields with the model
    // ID, so it answers "out of range" (upstream-vectors "Node group function
    // request for product information by software version"). A match sends
    // the product information, as a model ID match does upstream.
    let modelIDCase = try #require(
      Self.cases.first { $0.name == "group function request for product information by model ID" })
    var driver = EngineDriver(mode: .node, address: 23)
    driver.poll()
    driver.run(.until(500))
    driver.run(
      .groupFunction(
        to: 0x17, gfRequest(126996, 0xffff_ffff, 0xffff, 1, [field] + productField(value)),
        transportProtocol: true))
    driver.run(.until(600))
    // The frames sent match; the request itself differs.
    let sent = driver.events.map(\.description).filter { $0.contains(" tx ") }
    #expect(sent == modelIDCase.upstream.filter { $0.contains(" tx ") })
  }

  @Test func refusesProductFieldsThatDiffer() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.poll()
    driver.run(.until(500))
    driver.events = []
    driver.run(
      .groupFunction(to: 0x17, gfRequest(126996, 0xffff_ffff, 0xffff, 1, [4] + productField("9"))))
    // An acknowledgement of one pair, out of range.
    #expect(
      driver.events.map(\.description) == [
        "t=500 tx id=0x0ded4217 data=[0x00, 0x07, 0x02, 0x14, 0xf0, 0x01, 0x00, 0x01]",
        "t=500 tx id=0x0ded4217 data=[0x01, 0xf3, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]",
        "t=500 rx pgn=126208 priority=3 source=66 destination=23 data=[0x00, 0x14, 0xf0, 0x01, "
          + "0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x01, 0x04, 0x39, 0xff, 0xff, 0xff, 0xff, 0xff, "
          + "0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, "
          + "0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]",
      ])
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

  @Test func refusesTransportProtocolSendsWithAReason() {
    let long = Message(
      pgn: 126464, destination: 0x42, data: Array(0..<20), framing: .transportProtocol)
    var driver = EngineDriver(mode: .node, address: 23)
    driver.poll()
    driver.until(450)
    #expect(driver.send(long) == nil)
    #expect(driver.send(long) == .transferInProgress)

    var sender = EngineDriver(mode: .listenAndSend, address: 23)
    sender.poll()
    sender.until(200)
    #expect(sender.send(long) == .notAFullNode)
    #expect(
      sender.send(Message(pgn: 126464, data: Array(0..<224), framing: .transportProtocol))
        == .invalidMessage(.payloadTooLong(224)))
  }

  @Test func broadcastsTransportProtocolMessagesOfPDU2PGNs() {
    // Upstream's CheckDestination makes a PDU2 PGN broadcast.
    var driver = EngineDriver(mode: .node, address: 23)
    driver.poll()
    driver.until(450)
    driver.events = []
    driver.send(
      Message(pgn: 130820, destination: 0x42, data: Array(0..<10), framing: .transportProtocol))
    #expect(
      driver.events.first
        == .tx(at: 450, id: 0x18ec_ff17, data: [0x20, 10, 0, 2, 0xff, 0x04, 0xff, 0x01]))
  }

  @Test func reportsTransportProtocolDeadlines() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.poll()
    driver.until(450)
    driver.send(Message(pgn: 126464, data: Array(0..<20), framing: .transportProtocol))
    #expect(driver.engine.nextDeadline == 500)
    driver.until(650)
    #expect(driver.engine.nextDeadline == 10201)
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
    #expect(driver.engine.openRetryTime == 0)
    #expect(driver.engine.nextDeadline == nil)
    driver.poll()
    #expect(driver.engine.openRetryTime == 1000)
    #expect(driver.engine.nextDeadline == nil)
    driver.until(1000)
    #expect(driver.engine.openRetryTime == nil)
    #expect(driver.engine.nextDeadline == 1200)
    driver.until(1200)
    #expect(driver.engine.nextDeadline == 1450)
    // Then the heartbeat, due 10 s after opening, is sent once that has
    // passed.
    driver.until(1450)
    #expect(driver.engine.nextDeadline == 11201)
    driver.until(11210)
    #expect(driver.engine.nextDeadline == 71201)
  }

  @Test func sendsInformationAgainWhenTheTransportFails() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    let product = driver.engine.sendProductInformation(from: 0, to: 255, at: 500)
    let configuration = driver.engine.sendConfigurationInformation(from: 0, to: 255, at: 500)
    driver.engine.transmissionFailed(
      Array(product.dropFirst(2)) + configuration, retriesInformation: true, at: 510)
    #expect(driver.engine.devices[0].pendingProductInformation == 510 + 187 + 23 * 8)
    #expect(driver.engine.devices[0].pendingConfigurationInformation == 510 + 187 + 23 * 10)
  }

  @Test func leavesApplicationFailuresToTheApplication() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    let frames = driver.engine.sendProductInformation(from: 0, to: 255, at: 500)
    driver.engine.transmissionFailed(frames, retriesInformation: false, at: 510)
    #expect(driver.engine.devices[0].pendingProductInformation == nil)
  }

  @Test func endsATransferWhoseRequestToSendFails() throws {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    let message = Message(
      pgn: 126464, destination: 0x42, data: Array(0..<20), framing: .transportProtocol)
    let frames = try driver.engine.send(message, at: 500)
    driver.engine.transmissionFailed(frames, retriesInformation: false, at: 510)
    #expect(driver.engine.devices[0].transfer == nil)
  }

  @Test func keepsABroadcastTransferWhoseDataPacketFails() throws {
    // Upstream sends the next broadcast packet regardless.
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    let message = Message(pgn: 126464, data: Array(0..<20), framing: .transportProtocol)
    _ = try driver.engine.send(message, at: 500)
    let packet = driver.engine.poll(at: 550)
    #expect(packet.first?.id == 0x18eb_ff17)
    driver.engine.transmissionFailed(packet, retriesInformation: true, at: 560)
    #expect(driver.engine.devices[0].transfer != nil)
  }

  @Test func endsAnAddressedTransferWhoseDataPacketFails() throws {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    let message = Message(
      pgn: 126464, destination: 0x42, data: Array(0..<20), framing: .transportProtocol)
    _ = try driver.engine.send(message, at: 500)
    let packets = driver.engine.receive(
      CANFrame(id: 0x18ec_1742, data: [17, 3, 1, 0xff, 0xff, 0x00, 0xee, 0x01]), at: 510
    ).frames
    #expect(packets.first?.id == 0x18eb_4217)
    driver.engine.transmissionFailed(packets, retriesInformation: false, at: 520)
    #expect(driver.engine.devices[0].transfer == nil)
  }

  @Test(arguments: [Node.Mode.listenOnly, .listenAndSend, .node])
  func neverLeavesADeadlineInThePast(mode: Node.Mode) {
    // A deadline that polling doesn't move would make the node's timer fire
    // again at once, for ever. Only a full node sends heartbeats.
    var driver = EngineDriver(mode: mode, address: 23)
    while driver.now < 200_000 {
      driver.now += 10
      driver.poll()
      if let deadline = driver.engine.nextDeadline {
        #expect(deadline > driver.now, "at \(driver.now)")
        if deadline <= driver.now { return }
      }
    }
  }

  @Test func putsTheHeartbeatOffDuringAnAddressClaim() {
    // The heartbeat falls due while the device claims a new address; it goes
    // once the claim ends.
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(10100)
    driver.claim(from: 23, name: ownName - 1)
    while driver.now < 10500 {
      driver.now += 10
      driver.poll()
      if let deadline = driver.engine.nextDeadline {
        #expect(deadline > driver.now, "at \(driver.now)")
        if deadline <= driver.now { return }
      }
    }
  }

  @Test func dropsHalfReceivedMessagesWhenTheTransportCloses() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    let first = CANFrame(id: 0x09f8_0542, data: [0x20, 9, 1, 2, 3, 4, 5, 6])
    let last = CANFrame(id: 0x09f8_0542, data: [0x21, 7, 8, 9, 0xff, 0xff, 0xff, 0xff])
    #expect(driver.engine.receive(first, at: 500).message == nil)
    driver.engine.transportClosed()
    driver.until(800)
    #expect(driver.engine.receive(last, at: 800).message == nil)
  }

  @Test func hasNoDeadlinesWithoutAHeartbeat() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.engine.devices[0].heartbeatInterval = nil
    driver.until(500)
    #expect(driver.engine.nextDeadline == nil)
  }

  @Test func opensAgainAfterTheTransportCloses() {
    var driver = EngineDriver(mode: .node, address: 23)
    driver.until(500)
    driver.engine.transportClosed()
    #expect(driver.engine.openRetryTime == 0)
    #expect(driver.engine.nextDeadline == nil)
    driver.events = []
    // The next poll, at 510, opens the transport; the claim follows 200 ms later.
    driver.until(800)
    #expect(driver.events == [claimed(at: 710, from: 23)])
  }
}
