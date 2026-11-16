// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swift-nmea2000",
  products: [
    .library(name: "NMEA2000", targets: ["NMEA2000"])
  ],
  targets: [
    .target(name: "NMEA2000"),
    .testTarget(name: "NMEA2000Tests", dependencies: ["NMEA2000"]),
  ]
)
