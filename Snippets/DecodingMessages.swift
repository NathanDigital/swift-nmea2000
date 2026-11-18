// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Encodes and decodes messages, and defines a parameter group type. Run it
// with `scripts/linux-swift run DecodingMessages`.

import NMEA2000

// snippet.typed
// Encode a parameter group as a message, and decode it again.
let message = PositionRapidUpdate(latitude: 60.17, longitude: 24.94).makeMessage()
let position = try PositionRapidUpdate(message)
print(message.pgn, message.data, position.latitude ?? .nan)
// snippet.end

// snippet.catalog
// Decode a message of any PGN the library knows.
switch try message.decoded() {
case let position as PositionRapidUpdate: print("position", position)
case let wind as WindData: print("wind", wind)
case nil: print("no type for PGN", message.pgn)
default: break
}
// snippet.end

// snippet.custom
/// A parameter group of your own: a tank's level and capacity, on a
/// proprietary PGN.
struct TankReading: ParameterGroup {
  static let pgn: UInt32 = 65300
  static let defaultPriority: UInt8 = 6

  /// The tank's instance number.
  var instance: UInt8

  /// The level, in percent, or `nil` if not available.
  var level: Double?

  /// The capacity, in litres, or `nil` if not available.
  var capacity: Double?

  init(instance: UInt8, level: Double? = nil, capacity: Double? = nil) {
    self.instance = instance
    self.level = level
    self.capacity = capacity
  }

  // Read the fields in wire order.
  init(decoding reader: inout MessageReader) {
    instance = reader.readUInt8()
    level = reader.readInt16(resolution: 0.004)
    capacity = reader.readUInt32(resolution: 0.1)
  }

  // Write them in the same order.
  func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(instance)
    writer.appendInt16(level, resolution: 0.004)
    writer.appendUInt32(capacity, resolution: 0.1)
  }
}
// snippet.end

// snippet.custom-catalog
// Add the type to a catalog to decode it alongside the library's types.
let catalog = ParameterGroupCatalog.standard.adding(ParameterGroupCatalog([TankReading.self]))
let reading = TankReading(instance: 0, level: 75, capacity: 200).makeMessage()
if let tank = try reading.decoded(using: catalog) as? TankReading {
  print("tank", tank.instance, tank.level ?? .nan, "%")
}
// snippet.end
