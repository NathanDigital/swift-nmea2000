// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A CAN 2.0B frame with a 29-bit extended identifier, the unit a CAN
/// transport sends and receives.
///
/// Upstream passes frames between `tNMEA2000` and its CAN driver as separate
/// `id`, `len` and `buf` arguments (`CANSendFrame`, `CANGetFrame`).
public struct CANFrame: Sendable, Hashable, Codable {
  /// The most data bytes a classic CAN frame carries.
  public static let maxDataCount = 8

  /// The 29-bit extended identifier. ``CANIdentifier`` decodes it.
  public var id: UInt32

  /// The data bytes, at most ``maxDataCount`` of them.
  public var data: [UInt8]

  /// Creates a frame.
  ///
  /// - Parameters:
  ///   - id: The 29-bit extended identifier.
  ///   - data: The data bytes, at most ``maxDataCount`` of them.
  public init(id: UInt32, data: [UInt8]) {
    self.id = id
    self.data = data
  }
}

/// The message header fields that NMEA 2000 packs into a 29-bit CAN
/// identifier: priority, PGN, source and destination.
///
/// PGNs whose second byte is below 240 (PDU1 format) are addressed: the
/// identifier carries the destination in place of the PGN's low byte, which
/// must be zero. Other PGNs (PDU2 format) are always broadcast.
///
/// Ports upstream's `CanIdToN2k` and `N2ktoCanID`.
public struct CANIdentifier: Sendable, Hashable {
  /// The priority, from 0 (highest) to 7 (lowest).
  public var priority: UInt8

  /// The parameter group number.
  public var pgn: UInt32

  /// The source address.
  public var source: UInt8

  /// The destination address, or ``Message/broadcastAddress``.
  public var destination: UInt8

  /// Creates an identifier from header fields.
  ///
  /// - Parameters:
  ///   - priority: The priority. Only the low three bits are used.
  ///   - pgn: The parameter group number.
  ///   - source: The source address.
  ///   - destination: The destination address. PDU2 PGNs ignore it.
  public init(priority: UInt8, pgn: UInt32, source: UInt8, destination: UInt8) {
    self.priority = priority
    self.pgn = pgn
    self.source = source
    self.destination = destination
  }

  /// Decodes the header fields from a CAN identifier.
  ///
  /// Bits above the 29-bit identifier are ignored, as is the extended data
  /// page bit (bit 25). A PDU2 PGN decodes with the broadcast destination.
  ///
  /// Ports `CanIdToN2k`.
  ///
  /// - Parameter frameID: A 29-bit extended CAN identifier.
  public init(frameID: UInt32) {
    let pduFormat = UInt8(truncatingIfNeeded: frameID >> 16)
    let pduSpecific = UInt8(truncatingIfNeeded: frameID >> 8)
    let dataPage = (frameID >> 24) & 1
    priority = UInt8((frameID >> 26) & 0x7)
    source = UInt8(truncatingIfNeeded: frameID)
    if pduFormat < 240 {
      destination = pduSpecific
      pgn = dataPage << 16 | UInt32(pduFormat) << 8
    } else {
      destination = Message.broadcastAddress
      pgn = dataPage << 16 | UInt32(pduFormat) << 8 | UInt32(pduSpecific)
    }
  }

  /// A Boolean value that indicates whether the PGN is in PDU1 format, which
  /// carries a destination address.
  public var isAddressable: Bool {
    UInt8(truncatingIfNeeded: pgn >> 8) < 240
  }

  /// The 29-bit CAN identifier, or `nil` if the PGN can't be sent: a PDU1
  /// PGN whose low byte isn't zero, or a PGN wider than 18 bits.
  ///
  /// Ports `N2ktoCanID`. Upstream returns 0 for an invalid PDU1 PGN and
  /// doesn't check the PGN's width; a PGN that wide isn't valid on any bus.
  public var frameID: UInt32? {
    guard pgn <= 0x3_ffff else { return nil }
    let header = UInt32(priority & 0x7) << 26 | pgn << 8 | UInt32(source)
    if isAddressable {
      guard pgn & 0xff == 0 else { return nil }
      return header | UInt32(destination) << 8
    }
    return header
  }
}
