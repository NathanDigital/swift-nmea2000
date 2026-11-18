// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Lists the other devices on the bus. Run it with
// `scripts/linux-swift run DiscoveringDevices`.

import NMEA2000

// snippet.hide
/// One end of an in-memory CAN bus that joins two transports.
struct InMemoryTransport: CANTransport {
  private let received: AsyncStream<CANFrame>
  private let receiving: AsyncStream<CANFrame>.Continuation
  private let peer: AsyncStream<CANFrame>.Continuation

  /// Makes the two ends of a bus: what one sends, the other receives.
  static func makePair() -> (InMemoryTransport, InMemoryTransport) {
    let (first, toFirst) = AsyncStream.makeStream(of: CANFrame.self)
    let (second, toSecond) = AsyncStream.makeStream(of: CANFrame.self)
    return (
      InMemoryTransport(received: first, receiving: toFirst, peer: toSecond),
      InMemoryTransport(received: second, receiving: toSecond, peer: toFirst)
    )
  }

  /// Returns the frames the other end sends. The stream ends when the task
  /// reading it is cancelled, as the node expects.
  func open() async throws -> AsyncStream<CANFrame> { received }

  /// Delivers a frame to the other end. An unbounded stream never makes the
  /// sender wait; a hardware driver suspends here while its queue is full.
  func send(_ frame: CANFrame) async throws {
    try Task.checkCancellation()
    peer.yield(frame)
  }

  /// Ends the received frames.
  func close() async { receiving.finish() }
}

func makeDevice(uniqueNumber: UInt32, address: UInt8, model: String) -> Node.Device {
  Node.Device(
    address: address,
    name: DeviceName(
      uniqueNumber: uniqueNumber, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25),
    productInformation: ProductInformation(
      nmea2000Version: 2101, productCode: 1, modelID: model, softwareVersion: "1.0",
      modelVersion: "1", modelSerialCode: String(uniqueNumber)))
}

let (transport, otherTransport) = InMemoryTransport.makePair()
let device = makeDevice(uniqueNumber: 1, address: 20, model: "Display")
let other = Node(
  transport: otherTransport,
  configuration: .node(makeDevice(uniqueNumber: 2, address: 21, model: "Wind Sensor")))

// snippet.show
// snippet.configuration
var configuration = Node.Configuration.node(device)
configuration.discoversDevices = true
let node = Node(transport: transport, configuration: configuration)
// snippet.end

// snippet.events
try await withThrowingTaskGroup(of: Void.self) { group in
  group.addTask { try await node.run() }
  // snippet.hide
  group.addTask { try await other.run() }
  // snippet.show

  group.addTask {
    for await event in await node.events() where event == .deviceListChanged {
      for entry in await node.deviceList?.devices ?? [] {
        print(entry.address, entry.productInformation?.modelID ?? "not yet known")
        // snippet.hide
        if entry.productInformation != nil { return }
        // snippet.show
      }
    }
  }

  try await group.next()
  group.cancelAll()
}
// snippet.end
