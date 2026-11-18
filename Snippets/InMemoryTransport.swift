// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Implements a CANTransport, and joins two nodes with it. Run it with
// `scripts/linux-swift run InMemoryTransport`.

import NMEA2000

// snippet.transport
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
// snippet.end

// snippet.hide
func makeDevice(uniqueNumber: UInt32, address: UInt8) -> Node.Device {
  Node.Device(
    address: address,
    name: DeviceName(
      uniqueNumber: uniqueNumber, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25),
    productInformation: ProductInformation(
      nmea2000Version: 2101, productCode: 1, modelID: "Example", softwareVersion: "1.0",
      modelVersion: "1", modelSerialCode: String(uniqueNumber)))
}

// snippet.show
// snippet.nodes
let (sensorBus, displayBus) = InMemoryTransport.makePair()
let sensor = Node(
  transport: sensorBus, configuration: .node(makeDevice(uniqueNumber: 1, address: 20)))
let display = Node(
  transport: displayBus, configuration: .node(makeDevice(uniqueNumber: 2, address: 21)))

try await withThrowingTaskGroup(of: Void.self) { group in
  group.addTask { try await sensor.run() }
  group.addTask { try await display.run() }

  // The display prints the first wind data it receives.
  group.addTask {
    for await wind in await display.messages(of: WindData.self) {
      print("wind speed", wind.windSpeed ?? .nan, "m/s")
      return
    }
  }

  // The sensor sends wind data until the display has one.
  group.addTask {
    try await sensor.waitUntilReady()
    while true {
      try await sensor.send(WindData(reference: .apparent, windSpeed: 5.2, windAngle: 0.61))
      try await Task.sleep(for: .milliseconds(100))
    }
  }

  try await group.next()
  group.cancelAll()
}
// snippet.end
