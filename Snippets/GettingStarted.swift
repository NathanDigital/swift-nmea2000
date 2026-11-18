// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Runs a node that claims an address, listens for positions and sends wind
// data. Run it with `scripts/linux-swift run GettingStarted`.

import NMEA2000

// snippet.hide
/// A CAN bus with nothing else on it, which prints the frames the node sends.
/// See the InMemoryTransport snippet for a transport that carries frames.
struct PrintingTransport: CANTransport {
  func open() async throws -> AsyncStream<CANFrame> { AsyncStream.makeStream().stream }

  func send(_ frame: CANFrame) async throws {
    print("sent", String(frame.id, radix: 16), frame.data)
  }
}

let transport = PrintingTransport()

// snippet.show
// snippet.device
let device = Node.Device(
  name: DeviceName(
    uniqueNumber: 12345, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25),
  productInformation: ProductInformation(
    nmea2000Version: 2101, productCode: 1, modelID: "My Display", softwareVersion: "1.0",
    modelVersion: "1", modelSerialCode: "0001"),
  transmitPGNs: [WindData.pgn],
  receivePGNs: [PositionRapidUpdate.pgn])
// snippet.end

// snippet.node
let node = Node(
  transport: transport,  // your CANTransport
  configuration: .node(device))
// snippet.end

// snippet.run
try await withThrowingTaskGroup(of: Void.self) { group in
  // Runs the node until the bus closes or the task is cancelled.
  group.addTask { try await node.run() }

  // Receives positions, decoded.
  group.addTask {
    for await position in await node.messages(of: PositionRapidUpdate.self) {
      print(position.latitude ?? .nan, position.longitude ?? .nan)
    }
  }

  // Sends once the node has claimed its address.
  group.addTask {
    try await node.waitUntilReady()
    for _ in 1...3 {
      try await node.send(WindData(reference: .apparent, windSpeed: 5.2, windAngle: 0.61))
      try await Task.sleep(for: .seconds(1))
    }
  }

  // Stops the node when the first task ends.
  try await group.next()
  group.cancelAll()
}
// snippet.end
