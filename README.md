# swift-nmea2000

[![CI](https://github.com/NathanDigital/swift-nmea2000/actions/workflows/ci.yml/badge.svg)](https://github.com/NathanDigital/swift-nmea2000/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A pure-Swift port of **[Timo Lappalainen's NMEA2000 library](https://github.com/ttlappalainen/NMEA2000)**.

All of the protocol knowledge here comes from Timo Lappalainen's original C++ library: PGN definitions, field layouts, and address-claim and fast-packet behaviour. This project re-expresses that work as an idiomatic Swift package, written for Swift 6 with strict concurrency, value types and Swift Testing. Messages stay byte-for-byte compatible with the original on the NMEA 2000 bus.

> **Status: in development.** The port covers upstream's library ([coverage](docs/coverage.md)), and every part of it is tested against upstream's own code. Releases are tagged, but the API is not stable yet: see [API stability](#api-stability).

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
- **Linux only.** The supported platform is Ubuntu 26.04 LTS with the swift.org toolchain, on a Raspberry Pi or in the included Docker image. macOS and other Apple platforms aren't supported.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/NathanDigital/swift-nmea2000.git", exact: "0.1.0"),
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

The package has no dependencies of its own.

### API stability

Releases follow [Semantic Versioning](https://semver.org). Until 1.0, the API is still settling:

- A **minor** release (0.1 to 0.2) may change or remove public API. The release notes list what changed.
- A **patch** release (0.1.0 to 0.1.1) only fixes bugs and adds to the API, and doesn't break source that compiled against the same minor version.

So pin with `exact:` as above, or with `.upToNextMinor(from: "0.1.0")` to pick up patch releases, and expect to make changes when you move to the next minor version. A plain `from: "0.1.0"` would accept 0.2.0, which may not compile against your code.

The bytes sent on the bus are not part of this: they match upstream's library in every release, apart from the deliberate divergences listed in [`docs`](docs/README.md).

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
    configuration: .node(device))

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

## Documentation

- **Guides and API reference** are a DocC catalog in [`Sources/NMEA2000/NMEA2000.docc`](Sources/NMEA2000/NMEA2000.docc). The guides cover [getting started](Sources/NMEA2000/NMEA2000.docc/GettingStarted.md), [implementing a CAN transport](Sources/NMEA2000/NMEA2000.docc/ImplementingACANTransport.md), [hosting several devices](Sources/NMEA2000/NMEA2000.docc/HostingSeveralDevices.md), [decoding and encoding messages](Sources/NMEA2000/NMEA2000.docc/DecodingAndEncodingMessages.md), [gateway formats](Sources/NMEA2000/NMEA2000.docc/UsingGatewayFormats.md), [discovering devices](Sources/NMEA2000/NMEA2000.docc/DiscoveringDevices.md) and [coming from the C++ library](Sources/NMEA2000/NMEA2000.docc/ComingFromTheCPPLibrary.md). [Parameter groups](Sources/NMEA2000/NMEA2000.docc/ParameterGroups.md) lists the type for each PGN.
- **Examples** in [`Snippets`](Snippets) are complete programs that are compiled with the package. Run one in the build container with `scripts/linux-swift run GettingStarted`.
- **Porting notes** in [`docs`](docs/README.md) map each part of upstream's library to its Swift counterpart, and list where the port deliberately differs.

To build the documentation as a website:

```sh
scripts/linux-swift package --allow-writing-to-directory .docc-build \
    generate-documentation --target NMEA2000 --output-path .docc-build
```

## Building

The reference build environment is a pinned Docker image: Ubuntu 26.04 LTS with the Swift 6.4.2 toolchain from swift.org. Everyone builds against the same OS and compiler.

**Docker is required to build and test this repository.** `scripts/linux-swift` runs `swift` in that image, and every build, test, lint and documentation command goes through it. A Swift toolchain installed on the host isn't used and isn't supported, so Docker is the only thing to install:

```sh
scripts/linux-swift build
scripts/linux-swift test
scripts/linux-swift format lint -s -r Sources Tests Snippets Package.swift
```

See [docs/linux.md](docs/linux.md) for what is pinned and how to update it, and [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) before sending a change.

## Acknowledgements

This project would not exist without [NMEA2000](https://github.com/ttlappalainen/NMEA2000) by **Timo Lappalainen** (Kave Oy). His library has been developed in the open since 2015 and is widely used on embedded hardware. Please consider supporting the original project.

## License

MIT, the same license as the original library. [LICENSE](LICENSE) carries both copyright notices: © NathanDigital for this port, and © Timo Lappalainen, Kave Oy for the original work it is derived from.

## Disclaimer

This is an independent project. It is not affiliated with, endorsed by or certified by the National Marine Electronics Association (NMEA). NMEA 2000® is a registered trademark of the NMEA. This software has not been certified for NMEA 2000 compliance. Use it on a vessel at your own risk.
