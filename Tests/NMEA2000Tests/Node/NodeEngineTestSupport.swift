// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import Testing

@testable import NMEA2000

/// The NAME upstream's node claims with by default.
let ownName: UInt64 = 0xc032_8200_ffc0_0001

/// A node case from `Tools/UpstreamVectors/frames.cpp`: the steps it takes,
/// and the lines `scripts/upstream-vectors Node` prints for it: the frames
/// upstream's node sends, the messages it delivers and the sends it refuses.
struct NodeCase: Sendable, CustomTestStringConvertible {
  enum Step: Sendable {
    /// Poll every 10 ms until this many milliseconds into the case.
    case until(UInt64)
    /// Poll every `step` milliseconds until this many milliseconds into the
    /// case.
    case untilStepping(UInt64, step: UInt64)
    /// Receive a frame.
    case receive(UInt32, [UInt8])
    /// Send a message whose payload counts up from 0.
    case send(pgn: UInt32, count: Int, priority: UInt8)
    /// Send a message whose payload counts up from 0 by transport protocol.
    case sendTP(pgn: UInt32, count: Int, to: UInt8 = 0xff)
    /// Receive transport protocol data packets from 0x42 carrying a payload
    /// of `count` bytes counting up from 0.
    case dataPackets(to: UInt8, ClosedRange<Int>, of: Int)
    /// Receive an address claim with the first `count` bytes of a NAME.
    case claim(source: UInt8, name: UInt64, count: Int = 8)
    /// Receive an ISO request from 0x42; a count other than 3 pads or cuts
    /// the payload to that many bytes.
    case request(to: UInt8, pgn: UInt32, count: Int = 3)
    /// Receive a commanded address from 0x42 by transport protocol
    /// broadcast: a NAME and an address, plus `extra` bytes of 0x55.
    case command(name: UInt64, address: UInt8, extra: Int = 0)
    /// Receive a group function from 0x42 as a fast packet, or by transport
    /// protocol: a BAM when broadcast, otherwise a request to send.
    case groupFunction(to: UInt8, [UInt8], transportProtocol: Bool = false)
    /// Receive this many claims with a lower NAME, each from the node's
    /// address at the time.
    case lowerClaimsFromOwnAddress(Int)
    /// Receive wind data from a source every 100 ms until a time, as
    /// frames.cpp's `chatter` does.
    case chatter(source: UInt8, until: UInt64)
    /// Receive a message from 0x42, in a fast packet if it needs one.
    case inject(Message)
    /// Send a message from one of the node's devices.
    case sendMessage(Message, from: Int)
    /// Run an engine operation the application asks for, at the current
    /// time.
    case perform(@Sendable (inout NodeEngine, UInt64) -> [CANFrame])
    /// Forget the events so far.
    case clearEvents
  }

  /// An event, which prints as the harness prints it.
  enum Event: Hashable, Sendable, CustomStringConvertible {
    case tx(at: UInt64, id: UInt32, data: [UInt8])
    case rx(
      at: UInt64, pgn: UInt32, priority: UInt8, source: UInt8, destination: UInt8, data: [UInt8])
    case refused(at: UInt64)
    case line(String)

    var description: String {
      switch self {
      case .tx(let time, let id, let data):
        "t=\(time) tx id=\(hex(id, digits: 8)) data=\(bytes(data))"
      case .rx(let time, let pgn, let priority, let source, let destination, let data):
        "t=\(time) rx pgn=\(pgn) priority=\(priority) source=\(source) "
          + "destination=\(destination) data=\(bytes(data))"
      case .refused(let time): "t=\(time) send refused"
      case .line(let text): text
      }
    }
  }

  var name: String
  var mode: Node.Mode
  var address: UInt8 = 23
  var failedOpens = 0
  /// How many devices the node hosts, at `address` onwards with unique
  /// numbers from 1, as upstream's `SetDeviceCount` and `SetMode` give them.
  var deviceCount = 1
  /// The first device's extra transmit and receive PGNs.
  var transmitPGNs: [UInt32] = []
  var receivePGNs: [UInt32] = []
  var configuration: ConfigurationInformation? = .default
  var isoRequestHandler: Node.ISORequestHandler?
  var groupFunctionHandlers: [UInt32?: Node.GroupFunctionHandler] = [:]
  var discoversDevices = false
  var steps: [Step]
  var upstream: [String]

  var testDescription: String { name }
}

func hex(_ value: some BinaryInteger, digits: Int = 2) -> String {
  let text = String(value, radix: 16)
  return "0x" + String(repeating: "0", count: max(digits - text.count, 0)) + text
}

func bytes(_ data: [UInt8]) -> String {
  "[" + data.map { hex($0) }.joined(separator: ", ") + "]"
}

/// Drives an engine as the harness drives upstream's node: polling it the
/// way `ParseMessages` does, and opening the transport when it asks.
struct EngineDriver {
  var engine: NodeEngine
  var failedOpens: Int
  var now: UInt64 = 0
  var events: [NodeCase.Event] = []

  init(
    mode: Node.Mode, address: UInt8, failedOpens: Int = 0, deviceCount: Int = 1,
    transmitPGNs: [UInt32] = [], receivePGNs: [UInt32] = [],
    configuration: ConfigurationInformation? = .default,
    isoRequestHandler: Node.ISORequestHandler? = nil, discoversDevices: Bool = false
  ) {
    let devices = (0..<deviceCount).map { index in
      Node.Device(
        address: address + UInt8(index),
        name: DeviceName(
          uniqueNumber: 1 + UInt32(index), manufacturerCode: 2046, deviceFunction: 130,
          deviceClass: 25),
        productInformation: index == 0 ? .default : nil,
        transmitPGNs: index == 0 ? transmitPGNs : [], receivePGNs: index == 0 ? receivePGNs : [])
    }
    engine = NodeEngine(
      mode: mode, devices: devices, configurationInformation: configuration,
      discoversDevices: discoversDevices)
    engine.isoRequestHandler = isoRequestHandler
    self.failedOpens = failedOpens
  }

  mutating func poll() {
    openTransportIfDue()
    record(engine.poll(at: now))
  }

  /// Opens the transport when the engine asks, as upstream's `Open` does at
  /// the start of `ParseMessages`.
  mutating func openTransportIfDue() {
    guard let retryTime = engine.openRetryTime, now >= retryTime else { return }
    if failedOpens > 0 {
      failedOpens -= 1
      engine.transportFailedToOpen(at: now)
    } else {
      engine.transportOpened(at: now)
    }
  }

  mutating func until(_ time: UInt64, step: UInt64 = 10) {
    while now < time {
      now += min(step, time - now)
      poll()
    }
  }

  mutating func receive(_ frame: CANFrame) {
    openTransportIfDue()
    let (frames, message, deliveredAfter) = engine.receive(frame, at: now)
    record(Array(frames[..<deliveredAfter]))
    if let message {
      events.append(
        .rx(
          at: now, pgn: message.pgn, priority: message.priority, source: message.source,
          destination: message.destination, data: message.data))
    }
    record(Array(frames[deliveredAfter...]))
  }

  /// Sends a message, returning why the engine refused it, if it did.
  @discardableResult
  mutating func send(_ message: Message) -> NodeError? {
    poll()
    do {
      record(try engine.send(message, at: now))
      return nil
    } catch {
      events.append(.refused(at: now))
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
    case .untilStepping(let time, let step): until(time, step: step)
    case .receive(let id, let data): receive(CANFrame(id: id, data: data))
    case .send(let pgn, let count, let priority):
      send(Message(pgn: pgn, priority: priority, data: (0..<count).map(UInt8.init)))
    case .sendTP(let pgn, let count, let destination):
      send(
        Message(
          pgn: pgn, destination: destination, data: (0..<count).map(UInt8.init),
          framing: .transportProtocol))
    case .dataPackets(let destination, let sequences, let count):
      for sequence in sequences {
        receive(CANFrame(id: tpDT(to: destination), data: dataPacket(sequence, of: count)))
      }
    case .claim(let source, let name, let count): claim(from: source, name: name, count: count)
    case .request(let destination, let pgn, let count):
      var data = (0..<3).map { UInt8(truncatingIfNeeded: pgn >> (8 * $0)) }
      data = Array((data + repeatElement(0xff, count: max(count - 3, 0))).prefix(count))
      receive(CANFrame(id: 0x18ea_0042 | UInt32(destination) << 8, data: data))
    case .command(let name, let address, let extra):
      let payload =
        (0..<8).map { UInt8(truncatingIfNeeded: name >> (8 * $0)) } + [address]
        + repeatElement(0x55, count: extra)
      receive(CANFrame(id: tpCM(to: 0xff), data: bam(payload.count, 65240)))
      for sequence in 1...(payload.count + 6) / 7 {
        let bytes = payload.dropFirst((sequence - 1) * 7).prefix(7)
        receive(
          CANFrame(
            id: tpDT(to: 0xff),
            data: [UInt8(sequence)] + bytes + repeatElement(0xff, count: 7 - bytes.count)))
      }
    case .groupFunction(let destination, let payload, let transportProtocol):
      if transportProtocol {
        let start = destination == 0xff ? bam(payload.count, 126208) : rts(payload.count, 126208)
        receive(CANFrame(id: tpCM(to: destination), data: start))
        for sequence in 1...(payload.count + 6) / 7 {
          let bytes = payload.dropFirst((sequence - 1) * 7).prefix(7)
          receive(
            CANFrame(
              id: tpDT(to: destination),
              data: [UInt8(sequence)] + bytes + repeatElement(0xff, count: 7 - bytes.count)))
        }
      } else {
        let id = 0x0ded_0042 | UInt32(destination) << 8
        let first = Array(payload.prefix(6))
        receive(
          CANFrame(
            id: id,
            data: [0x00, UInt8(payload.count)] + first + repeatElement(0xff, count: 6 - first.count)
          ))
        var frame = 1
        while 6 + (frame - 1) * 7 < payload.count {
          let bytes = payload.dropFirst(6 + (frame - 1) * 7).prefix(7)
          receive(
            CANFrame(
              id: id, data: [UInt8(frame)] + bytes + repeatElement(0xff, count: 7 - bytes.count)))
          frame += 1
        }
      }
    case .chatter(let source, let time):
      while now < time {
        until(min(now + 100, time))
        receive(
          CANFrame(
            id: 0x09fd_0200 | UInt32(source),
            data: [0x01, 0xf4, 0x01, 0x10, 0x27, 0x00, 0xff, 0xff]))
      }
    case .inject(let message):
      var framer = MessageFramer()
      var message = message
      message.source = 0x42
      for frame in (try? framer.frames(for: message)) ?? [] { receive(frame) }
    case .lowerClaimsFromOwnAddress(let count):
      for _ in 0..<count { claim(from: engine.address, name: ownName - 1) }
    case .sendMessage(let message, let device):
      poll()
      do {
        record(try engine.send(message, from: device, at: now))
      } catch {
        // Upstream's SendMsg returns false without the harness recording it.
      }
    case .perform(let operation):
      poll()
      record(operation(&engine, now))
    case .clearEvents: events = []
    }
  }

  /// Appends the device list's state, as frames.cpp's `dumpDevices` prints
  /// it.
  mutating func dumpDevices() {
    guard let list = engine.deviceList else { return }
    // Upstream's ReadResetIsListUpdated: whether the list changed since the
    // last dump.
    let isUpdated = engine.takeOutput().events.contains(.deviceListChanged)
    events.append(.line("devices count=\(list.count) updated=\(isUpdated ? 1 : 0)"))
    for device in list.devices {
      let name = String(device.name?.rawValue ?? 0, radix: 16)
      events.append(
        .line(
          "device source=\(device.address) name=0x"
            + String(repeating: "0", count: 16 - name.count) + name))
      let product = device.productInformation
      events.append(
        .line(
          "product version=\(product?.nmea2000Version ?? 0) code=\(product?.productCode ?? 0) "
            + "cert=\(product?.certificationLevel ?? 0) load=\(product?.loadEquivalency ?? 0) "
            + "model=\(product?.modelID ?? "") sw=\(product?.softwareVersion ?? "") "
            + "version=\(product?.modelVersion ?? "") serial=\(product?.modelSerialCode ?? "")"))
      let configuration = device.configurationInformation
      events.append(
        .line(
          "config manufacturer=\(configuration?.manufacturerInformation ?? "") "
            + "installation1=\(configuration?.installationDescription1 ?? "") "
            + "installation2=\(configuration?.installationDescription2 ?? "")"))
      let pgns = { (list: [UInt32]?) in
        list.map { "[" + $0.map(String.init).joined(separator: ", ") + "]" } ?? "-"
      }
      events.append(
        .line("pgns transmit=\(pgns(device.transmitPGNs)) receive=\(pgns(device.receivePGNs))"))
    }
  }

  private mutating func record(_ frames: [CANFrame]) {
    events += frames.map { .tx(at: now, id: $0.id, data: $0.data) }
  }
}

let claim17: [UInt8] = [0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]
let position: [UInt8] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
let sendPosition = NodeCase.Step.send(pgn: 129025, count: 8, priority: 2)
/// Answers requests for 130306 with a one-byte message, and refuses others,
/// as frames.cpp's `requestHandler` does.
let requestHandler: Node.ISORequestHandler = { request in
  guard request.pgn == 130306 else { return nil }
  return [Message(pgn: 130306, destination: request.requester, data: [request.requester])]
}

/// Answers requests for 130306 from the second device only, as frames.cpp's
/// `deviceRequestHandler` does.
let deviceRequestHandler: Node.ISORequestHandler = { request in
  guard request.pgn == 130306, request.device == 1 else { return nil }
  return [
    Message(
      pgn: 130306, destination: request.requester, data: [UInt8(request.device.rawValue)])
  ]
}

/// Handles group functions for 130310 as frames.cpp's
/// `AppGroupFunctionHandler` does: acknowledges requests itself, answers
/// reads with one field, and leaves the rest to the node.
let appGroupFunctionHandler: Node.GroupFunctionHandler = { request in
  switch request.code {
  case .request:
    return [
      GroupFunction.Acknowledgement.uniform(
        pgn: 130310, pgnError: .acknowledge, transmissionError: .acknowledge,
        pairCount: request.requestParameters.pairCount, parameterError: .outOfRange
      ).makeMessage(destination: request.requester)
    ]
  case .read:
    let read = request.readOrWriteParameters
    var reply = GroupFunction.Reply(
      answering: request, selectionPairCount: read.selectionPairCount,
      parameterPairCount: read.parameterPairCount)
    reply.writer.appendUInt8(1)
    reply.writer.appendUInt8(0x2a)
    return [reply.makeMessage(destination: request.requester)]
  default:
    return nil
  }
}

/// The GNSS position frames.cpp's "devices send from each" case sends.
let gnssPosition = Message(
  pgn: 129029, priority: 3,
  data: [
    0x01, 0x50, 0x46, 0x00, 0x51, 0x25, 0x02, 0x00, 0x80, 0x02, 0xd6, 0x50, 0x2e, 0x57, 0x08,
    0x00, 0x80, 0x12, 0x45, 0x2e, 0xa0, 0x74, 0x03, 0x80, 0x96, 0x98, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x10, 0xfd, 0x0c, 0x50, 0x00, 0x32, 0x00, 0xdc, 0x05, 0x00, 0x00, 0x01, 0xf0, 0x00,
    0xc8, 0x00,
  ])

// Group function payloads, as frames.cpp builds them.

func gf(_ code: UInt8, _ pgn: UInt32, _ rest: [UInt8]) -> [UInt8] {
  [code, UInt8(pgn & 0xff), UInt8(pgn >> 8 & 0xff), UInt8(pgn >> 16 & 0xff)] + rest
}

func gfRequest(
  _ pgn: UInt32, _ interval: UInt32, _ offset: UInt16, _ pairs: UInt8, _ fields: [UInt8] = []
) -> [UInt8] {
  let intervalBytes = (0..<4).map { UInt8(truncatingIfNeeded: interval >> (8 * $0)) }
  return gf(0, pgn, intervalBytes + [UInt8(offset & 0xff), UInt8(offset >> 8), pairs] + fields)
}

func gfCommand(_ pgn: UInt32, _ priority: UInt8, _ pairs: UInt8, _ fields: [UInt8] = [])
  -> [UInt8]
{
  gf(1, pgn, [0xf0 | priority, pairs] + fields)
}

func varStr(_ text: String) -> [UInt8] {
  [UInt8(text.utf8.count + 2), 1] + Array(text.utf8)
}

/// A 32-byte product information string field.
func productField(_ text: String) -> [UInt8] {
  Array(text.utf8) + repeatElement(0xff, count: 32 - text.utf8.count)
}

let fastPacketStart: [UInt8] = [0x00, 9, 1, 2, 3, 4, 5, 6]

func claimed(at time: UInt64, from source: UInt8) -> NodeCase.Event {
  .tx(at: time, id: 0x18ee_ff00 | UInt32(source), data: claim17)
}

// Transport protocol frames from 0x42, as frames.cpp builds them.

func tpCM(to destination: UInt8) -> UInt32 { 0x18ec_0042 | UInt32(destination) << 8 }
func tpDT(to destination: UInt8) -> UInt32 { 0x18eb_0042 | UInt32(destination) << 8 }

func cm(
  _ control: UInt8, _ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8, _ pgn: UInt32
) -> [UInt8] {
  [control, a, b, c, d, UInt8(pgn & 0xff), UInt8(pgn >> 8 & 0xff), UInt8(pgn >> 16)]
}

func rts(_ count: Int, _ pgn: UInt32, packets: UInt8? = nil) -> [UInt8] {
  cm(16, UInt8(count & 0xff), UInt8(count >> 8), packets ?? UInt8((count + 6) / 7), 0xff, pgn)
}

func bam(_ count: Int, _ pgn: UInt32) -> [UInt8] {
  cm(32, UInt8(count & 0xff), UInt8(count >> 8), UInt8((count + 6) / 7), 0xff, pgn)
}

func cts(_ packets: UInt8, next: UInt8, _ pgn: UInt32) -> [UInt8] {
  cm(17, packets, next, 0xff, 0xff, pgn)
}

/// Data packet `sequence` of a payload of `count` bytes counting up from 0.
func dataPacket(_ sequence: Int, of count: Int) -> [UInt8] {
  [UInt8(sequence)] + ((sequence - 1) * 7..<sequence * 7).map { $0 < count ? UInt8($0) : 0xff }
}
