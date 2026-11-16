# swift-nmea2000

[![CI](https://github.com/NathanDigital/swift-nmea2000/actions/workflows/ci.yml/badge.svg)](https://github.com/NathanDigital/swift-nmea2000/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A pure-Swift port of **[Timo Lappalainen's NMEA2000 library](https://github.com/ttlappalainen/NMEA2000)**.

All of the protocol knowledge here comes from Timo Lappalainen's original C++ library: PGN definitions, field layouts, and address-claim and fast-packet behaviour. This project re-expresses that work as an idiomatic Swift package, written for Swift 6 with strict concurrency, value types and Swift Testing. Messages stay byte-for-byte compatible with the original on the NMEA 2000 bus.

> **Status: early development.** The package structure is in place and the port is under way. The API is not stable yet.

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
