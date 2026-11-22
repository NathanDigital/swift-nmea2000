// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Bridges a bus and an Actisense gateway connection in both directions. Run
// it with `scripts/linux-swift run GatewayBridge`.

import NMEA2000

// snippet.hide
/// A CAN bus with nothing else on it, which prints the frames the node sends.
/// See the InMemoryTransport snippet for a transport that carries frames.
struct PrintingTransport: CANTransport {
  func open() async throws -> AsyncStream<CANFrame> { AsyncStream.makeStream().stream }

  func send(_ frame: CANFrame) async throws {
    print("to bus", String(frame.id, radix: 16), frame.data)
  }
}

/// Stands in for a serial port: the bytes a PC program sends, and somewhere
/// to write the bytes for it.
struct SerialPort: Sendable {
  let bytes: AsyncStream<[UInt8]>

  func write(_ bytes: [UInt8]) {
    print("to serial port", bytes)
  }
}

// The PC program sends one message, in two chunks, and keeps the port open.
let wind = WindData(reference: .apparent, windSpeed: 5.2, windAngle: 0.61).makeMessage()
let incoming = try Actisense.encode(wind)
let (serialBytes, serialInput) = AsyncStream.makeStream(of: [UInt8].self)
serialInput.yield(Array(incoming.prefix(5)))
serialInput.yield(Array(incoming.dropFirst(5)))

let transport = PrintingTransport()
let serialPort = SerialPort(bytes: serialBytes)

// snippet.show
// snippet.node
// A gateway receives everything, and sends from an address it doesn't claim.
let node = Node(transport: transport, configuration: .listenAndSend(address: 25))

// Ask for the messages before the node runs, so that none are missed.
let messages = await node.messages(includingSent: true)
// snippet.end

// snippet.bridge
try await withThrowingTaskGroup(of: Void.self) { group in
  group.addTask { try await node.run() }

  // Bus to gateway: encode each message and write its bytes.
  group.addTask {
    for await message in messages {
      serialPort.write(try Actisense.encode(message))
      // snippet.hide
      return
      // snippet.show
    }
  }

  // Gateway to bus: decode the bytes as they arrive, and send each message.
  group.addTask {
    try await node.waitUntilReady()
    var decoder = Actisense.Decoder()
    for await bytes in serialPort.bytes {
      for message in decoder.decode(bytes, at: .zero) {
        try await node.send(message)
      }
    }
  }

  try await group.next()
  group.cancelAll()
}
// snippet.end
