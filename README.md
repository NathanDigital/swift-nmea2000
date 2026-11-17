# swift-nmea2000

[![CI](https://github.com/NathanDigital/swift-nmea2000/actions/workflows/ci.yml/badge.svg)](https://github.com/NathanDigital/swift-nmea2000/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A pure-Swift port of **[Timo Lappalainen's NMEA2000 library](https://github.com/ttlappalainen/NMEA2000)**.

All of the protocol knowledge here comes from Timo Lappalainen's original C++ library: PGN definitions, field layouts, and address-claim and fast-packet behaviour. This project re-expresses that work as an idiomatic Swift package, written for Swift 6 with strict concurrency, value types and Swift Testing. Messages stay byte-for-byte compatible with the original on the NMEA 2000 bus.

> **Status: in development.** The port covers upstream's library, and every part of it is tested against upstream's own code. The API is not stable yet, and there are no tagged releases.

## What's included

- **Messages:** every PGN in upstream's `N2kMessages`, plus the network management PGNs, each as a typed value (`PositionRapidUpdate`, `WindData`, `ProductInformation` and so on) that encodes and decodes exactly as upstream does.
- **A node:** `Node`, an actor that runs on any CAN bus you connect through the `CANTransport` protocol. It claims an address and defends it, sends and reassembles fast packets and ISO transport protocol sessions, answers ISO requests and group functions, sends heartbeats, and can keep a list of the other devices on the bus.
- **Gateway formats:** codecs for the Actisense serial format and SeaSmart `$PCDIN` sentences.
- **Proprietary PGNs:** upstream's Maretron and CZone messages.

CAN hardware drivers aren't part of this package: implement `CANTransport` for your interface, such as SocketCAN.

## Goals

- **Wire compatibility.** Every PGN encodes and decodes exactly as the upstream library does, so devices interoperate on the bus.
- **Easy porting of upstream changes.** New PGNs and PGN fixes added upstream can be brought across directly. See [docs/upstream-sync.md](docs/upstream-sync.md).
- **Idiomatic Swift.** Follows the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/): typed messages, optionals for "data not available", and `async` APIs instead of callbacks.
- **Linux first.** Ubuntu 26.04 LTS with the swift.org toolchain is the reference platform.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NathanDigital/swift-nmea2000.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "NMEA2000", package: "swift-nmea2000"),
    ]),
]
```

```swift
import NMEA2000
```

Tagged releases will follow once the API settles.

## Usage

```swift
import NMEA2000

let device = Node.Device(
    name: DeviceName(
        uniqueNumber: 12345, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25),
    productInformation: ProductInformation(
        nmea2000Version: 2101, productCode: 1, modelID: "My Display", softwareVersion: "1.0",
        modelVersion: "1", modelSerialCode: "0001"))
let node = Node(
    transport: transport,  // your CANTransport
    configuration: .node(device, configurationInformation: nil))

try await withThrowingTaskGroup(of: Void.self) { group in
    group.addTask { try await node.run() }

    // Receive positions, decoded.
    group.addTask {
        for await position in await node.messages(of: PositionRapidUpdate.self) {
            print(position.latitude ?? .nan, position.longitude ?? .nan)
        }
    }

    // Send once the node has claimed its address.
    group.addTask {
        try await node.waitUntilReady()
        try await node.send(PositionRapidUpdate(latitude: 60.17, longitude: 24.94))
    }

    try await group.waitForAll()
}
```

To handle several kinds of message, decode each with the parameter group type for its PGN:

```swift
for await message in await node.messages() {
    switch try? message.decoded() {
    case let position as PositionRapidUpdate: print(position)
    case let wind as WindData: print(wind)
    default: break
    }
}
```

The [docs](docs/) map each part of upstream's library to its Swift counterpart, and list where the port deliberately differs.

## Building

The reference build environment is a pinned Docker image: Ubuntu 26.04 LTS with the Swift 6.4.2 toolchain from swift.org. Everyone builds against the same OS and compiler:

```sh
scripts/linux-swift build
scripts/linux-swift test
scripts/linux-swift format lint -s -r Sources
```

See [docs/linux.md](docs/linux.md) for what is pinned and how to update it.

## Acknowledgements

This project would not exist without [NMEA2000](https://github.com/ttlappalainen/NMEA2000) by **Timo Lappalainen** (Kave Oy). His library has been developed in the open since 2015 and is widely used on embedded hardware. Please consider supporting the original project.

## License

MIT, the same license as the original library. [LICENSE](LICENSE) contains the copyright notices for this port (© NathanDigital) and for the original work (© Timo Lappalainen, Kave Oy).

## Disclaimer

This is an independent project. It is not affiliated with, endorsed by or certified by the National Marine Electronics Association (NMEA). NMEA 2000® is a registered trademark of the NMEA. This software has not been certified for NMEA 2000 compliance. Use it on a vessel at your own risk.
