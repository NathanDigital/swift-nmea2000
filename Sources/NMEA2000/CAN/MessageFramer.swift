// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Splits messages into the CAN frames that carry them: a single frame, or a
/// fast packet of up to 32 frames.
///
/// A fast packet's first frame holds a sequence/frame byte, the payload
/// length and six payload bytes; each following frame holds the
/// sequence/frame byte and seven more bytes, with the last one padded with
/// `0xff`. The framer keeps upstream's per-PGN sequence counters, so it
/// produces the same frames as upstream for the same sequence of messages.
///
/// ISO transport protocol messages aren't framed here; the node runs that
/// protocol as a session with the receiver.
///
/// Ports the single-frame and fast-packet paths of `tNMEA2000::SendMsg` and
/// `tNMEA2000::GetSequenceCounter`.
public struct MessageFramer: Sendable {
  /// The PGNs every upstream node transmits: ISO acknowledgement, ISO
  /// request, transport protocol, ISO address claim, group function, PGN
  /// list, heartbeat, product information and configuration information.
  ///
  /// Ports `DefTransmitMessages`.
  public static let defaultTransmitPGNs: [UInt32] = [
    59392, 59904, 60160, 60416, 60928, 126208, 126464, 126993, 126996, 126998,
  ]

  /// The catalog that decides which PGNs are sent as fast packets.
  public let catalog: PGNCatalog

  private var sequenceCounters: SequenceCounters

  /// Creates a framer.
  ///
  /// - Parameters:
  ///   - catalog: The catalog that decides which PGNs are sent as fast
  ///     packets.
  ///   - transmitPGNs: The PGNs the device transmits beyond
  ///     ``defaultTransmitPGNs``. Each fast-packet PGN in either list gets a
  ///     sequence counter of its own, handed out in the order PGNs are first
  ///     sent; any others share one counter, as upstream does.
  public init(catalog: PGNCatalog = PGNCatalog(), transmitPGNs: [UInt32] = []) {
    self.catalog = catalog
    let count = (Self.defaultTransmitPGNs + transmitPGNs).count(where: catalog.isFastPacket)
    sequenceCounters = SequenceCounters(dedicatedCount: count)
  }

  /// Returns the frames that carry a message.
  ///
  /// A message of up to eight bytes whose PGN isn't a fast-packet PGN goes in
  /// one frame. Any other message goes in a fast packet, which advances that
  /// PGN's sequence counter.
  ///
  /// A fast packet shorter than six bytes is padded with `0xff`. Upstream
  /// sends whatever its message buffer held in those bytes.
  ///
  /// - Parameter message: The message to send. Its source must be a valid
  ///   bus address (0–251), except for an ISO address claim.
  /// - Returns: The frames to send, in order.
  /// - Throws: ``FramingError`` if the message can't be sent.
  public mutating func frames(for message: Message) throws(FramingError) -> [CANFrame] {
    if message.source > Self.maxBusAddress && message.pgn != Self.addressClaimPGN {
      throw .invalidSource(message.source)
    }
    let header = CANIdentifier(
      priority: message.priority, pgn: message.pgn, source: message.source,
      destination: message.destination)
    guard message.pgn != 0, let id = header.frameID else { throw .invalidPGN(message.pgn) }
    guard message.data.count <= Message.maxDataCount else {
      throw .payloadTooLong(message.data.count)
    }

    let data = message.data
    if data.count <= CANFrame.maxDataCount && !catalog.isFastPacket(message.pgn) {
      return [CANFrame(id: id, data: data)]
    }

    let sequence = sequenceCounters.next(for: message.pgn) << 5
    let frameCount = data.count > 6 ? (data.count - 6 - 1) / 7 + 2 : 1
    var frames: [CANFrame] = []
    frames.reserveCapacity(frameCount)
    var first = [sequence, UInt8(data.count)] + data.prefix(6)
    first += repeatElement(0xff, count: CANFrame.maxDataCount - first.count)
    frames.append(CANFrame(id: id, data: first))
    var offset = 6
    for index in 1..<frameCount {
      var bytes = [sequence | UInt8(index)] + data[offset..<min(offset + 7, data.count)]
      bytes += repeatElement(0xff, count: CANFrame.maxDataCount - bytes.count)
      frames.append(CANFrame(id: id, data: bytes))
      offset += 7
    }
    return frames
  }

  /// The highest address a device can claim (`N2kMaxCanBusAddress`).
  static let maxBusAddress: UInt8 = 251

  /// The ISO address claim PGN, the one PGN a device may send without a
  /// valid address.
  static let addressClaimPGN: UInt32 = 60928
}

/// Why a message can't be split into frames.
public enum FramingError: Error, Sendable, Hashable {
  /// The PGN is zero, a PDU1 PGN with a nonzero low byte, or wider than 18
  /// bits.
  case invalidPGN(UInt32)
  /// The source isn't a valid bus address (0–251).
  case invalidSource(UInt8)
  /// The payload is longer than ``Message/maxDataCount``.
  case payloadTooLong(Int)
}

/// Fast-packet sequence counters, three bits per PGN.
///
/// Ports `tNMEA2000::GetSequenceCounter`, including its quirks: a PGN's first
/// fast packet uses sequence 0, PGNs get dedicated counters in the order they
/// are first sent until the dedicated slots run out, and the remaining PGNs
/// share one counter that is advanced before its first use.
struct SequenceCounters: Sendable {
  private var dedicated: [(pgn: UInt32, counter: UInt8)?]
  private var shared: UInt8 = 0

  init(dedicatedCount: Int) {
    dedicated = Array(repeating: nil, count: dedicatedCount)
  }

  mutating func next(for pgn: UInt32) -> UInt8 {
    for index in dedicated.indices {
      guard let slot = dedicated[index] else {
        dedicated[index] = (pgn, 0)
        return 0
      }
      if slot.pgn == pgn {
        let counter = (slot.counter + 1) & 0x7
        dedicated[index] = (pgn, counter)
        return counter
      }
    }
    shared = (shared + 1) & 0x7
    return shared
  }
}
