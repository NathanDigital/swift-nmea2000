// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swift-nmea2000",
  products: [
    .library(name: "NMEA2000", targets: ["NMEA2000"])
  ],
  targets: [
    .target(
      name: "NMEA2000",
      // The field codec rounds with `rounded(_:)`, which calls libm on x86-64. An executable
      // that imports neither Foundation nor Glibc doesn't link libm by itself.
      linkerSettings: [.linkedLibrary("m", .when(platforms: [.linux]))]),
    .testTarget(name: "NMEA2000Tests", dependencies: ["NMEA2000"]),
  ]
)

// The DocC plugin builds the documentation (`swift package generate-documentation`).
// It is only a dependency when NMEA2000_ENABLE_DOCC is set, which `scripts/linux-swift`
// does for documentation commands, so packages that use this one don't fetch it.
if Context.environment["NMEA2000_ENABLE_DOCC"] != nil {
  package.dependencies.append(
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.1.0"))
}
