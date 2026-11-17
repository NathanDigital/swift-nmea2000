// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The shared layout of PGNs 127501 and 127502: an instance byte followed by
/// 28 two-bit statuses.
///
/// Upstream packs this as a `uint64_t` (`tN2kBinaryStatus`) shifted left by
/// eight bits, with unset statuses all ones (`N2kResetBinaryStatus`).
enum SwitchBank {
  /// The number of statuses in one bank.
  static let statusCount = 28

  static func encode(instance: UInt8, statuses: [OnOffStatus], to writer: inout MessageWriter) {
    var bank = UInt64.max
    for (index, status) in statuses.prefix(statusCount).enumerated() {
      let shift = UInt64(2 * index)
      bank = bank & ~(0x03 << shift) | UInt64(status.rawValue & 0x03) << shift
    }
    writer.appendUInt64(bank << 8 | UInt64(instance))
  }

  static func decode(from reader: inout MessageReader) -> (instance: UInt8, statuses: [OnOffStatus])
  {
    let instance = reader.readUInt8()
    // Read what is present; missing bytes leave their statuses unavailable.
    var bank = UInt64.max
    for byte in 0..<7 where reader.remainingCount > 0 {
      let shift = UInt64(8 * byte)
      bank = bank & ~(0xff << shift) | UInt64(reader.readUInt8()) << shift
    }
    let statuses = (0..<statusCount).map {
      OnOffStatus(rawValue: UInt8(truncatingIfNeeded: bank >> UInt64(2 * $0)) & 0x03)
    }
    return (instance, statuses)
  }
}
