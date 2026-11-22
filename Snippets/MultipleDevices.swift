// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Runs one node that appears on the bus as two devices, a temperature monitor
// and a battery monitor. Run it with `scripts/linux-swift run MultipleDevices`.

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
// snippet.devices
let temperatureMonitor = Node.Device(
  address: 22,
  name: DeviceName(
    uniqueNumber: 112233, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 75),
  productInformation: ProductInformation(
    nmea2000Version: 2101, productCode: 100, modelID: "Temperature Monitor",
    softwareVersion: "1.0", modelVersion: "1", modelSerialCode: "112233"),
  transmitPGNs: [Temperature.pgn])

let batteryMonitor = Node.Device(
  address: 23,
  name: DeviceName(
    uniqueNumber: 112234, manufacturerCode: 2046, deviceFunction: 170, deviceClass: 35),
  productInformation: ProductInformation(
    nmea2000Version: 2101, productCode: 101, modelID: "Battery Monitor",
    softwareVersion: "1.0", modelVersion: "1", modelSerialCode: "112234"),
  transmitPGNs: [BatteryStatus.pgn])
// snippet.end

// snippet.node
let node = Node(
  transport: transport,
  configuration: Node.Configuration(mode: .node, devices: [temperatureMonitor, batteryMonitor]))

// A device's ID is its position in the configuration's devices.
let temperature: Node.DeviceID = 0
let battery: Node.DeviceID = 1
// snippet.end

// snippet.send
try await withThrowingTaskGroup(of: Void.self) { group in
  group.addTask { try await node.run() }

  group.addTask {
    // Each device claims its own address.
    try await node.waitUntilReady(temperature)
    try await node.waitUntilReady(battery)
    for _ in 1...3 {
      try await node.send(
        Temperature(instance: 1, source: .mainCabin, actualTemperature: 295.65),
        from: temperature)
      try await node.send(
        BatteryStatus(batteryInstance: 1, voltage: 13.87, current: 5.12, temperature: 308.27),
        from: battery)
      try await Task.sleep(for: .seconds(1))
    }
  }

  try await group.next()
  group.cancelAll()
}
// snippet.end
