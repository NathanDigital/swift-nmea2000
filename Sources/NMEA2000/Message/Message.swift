// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A single NMEA 2000 message: its header fields and data payload.
///
/// Ports upstream's `tN2kMsg` container. The field-level helpers that upstream
/// puts on `tN2kMsg` (`AddByte`, `Get2ByteUDouble`, …) live on
/// ``MessageWriter`` and ``MessageReader`` instead.
public struct Message: Sendable, Hashable {
  /// The largest payload a message can carry, in bytes.
  ///
  /// This is the fast-packet limit, matching upstream's `tN2kMsg::MaxDataLen`.
  public static let maxDataCount = 223

  /// The broadcast destination address.
  public static let broadcastAddress: UInt8 = 0xff

  /// The message priority, from 0 (highest) to 7 (lowest).
  public var priority: UInt8

  /// The parameter group number that identifies the message's contents.
  public var pgn: UInt32

  /// The source address of the sending device.
  public var source: UInt8

  /// The destination address, or ``broadcastAddress`` for a broadcast.
  public var destination: UInt8

  /// The payload bytes.
  public var data: [UInt8]

  /// The time the message was created or received, in milliseconds.
  ///
  /// The epoch is set by whoever stamps the message, usually the node's clock.
  /// Gateway formats such as Actisense carry this value on the wire.
  public var timestamp: UInt32

  /// A Boolean value that indicates whether the message is sent or was
  /// received using the ISO transport protocol rather than fast packet.
  public var isTransportProtocol: Bool

  /// A Boolean value that indicates whether a message of up to eight bytes
  /// is sent in a single frame even if its PGN is a fast-packet PGN, as some
  /// devices expect. Longer messages are sent as fast packets regardless.
  ///
  /// Upstream asks for this with a priority of `0x80` or more.
  public var forcesSingleFrame: Bool = false

  /// Creates a message.
  ///
  /// - Parameters:
  ///   - pgn: The parameter group number.
  ///   - priority: The priority. Only the low three bits are kept.
  ///   - source: The source address.
  ///   - destination: The destination address.
  ///   - data: The payload bytes.
  ///   - timestamp: The time stamp, in milliseconds.
  ///   - isTransportProtocol: Whether the message uses the ISO transport
  ///     protocol.
  public init(
    pgn: UInt32,
    priority: UInt8 = 6,
    source: UInt8 = 15,
    destination: UInt8 = Message.broadcastAddress,
    data: [UInt8] = [],
    timestamp: UInt32 = 0,
    isTransportProtocol: Bool = false
  ) {
    self.pgn = pgn
    self.priority = priority & 0x7
    self.source = source
    self.destination = destination
    self.data = data
    self.timestamp = timestamp
    self.isTransportProtocol = isTransportProtocol
  }

  /// A Boolean value that indicates whether the message has a PGN and a
  /// non-empty payload.
  public var isValid: Bool {
    pgn != 0 && !data.isEmpty
  }
}

extension Message: CustomStringConvertible {
  /// The message's header and payload, as upstream's `tN2kMsg::Print` writes
  /// them without its time prefix: `Pri:2 PGN:127250 Source:1 Dest:255
  /// Len:4 Data:1,a,ff,0`, with the payload in hex.
  public var description: String {
    "Pri:\(priority) PGN:\(pgn) Source:\(source) Dest:\(destination) Len:\(data.count) Data:"
      + data.map { String($0, radix: 16) }.joined(separator: ",")
  }
}
