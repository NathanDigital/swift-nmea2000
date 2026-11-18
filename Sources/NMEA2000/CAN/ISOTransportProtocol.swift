// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The ISO transport protocol (ISO 11783-3), which carries a message in a
/// session of 7-byte data packets: broadcast with a BAM announcement, or sent
/// to one device that paces the sender with clear-to-send messages.
///
/// Ports the `TP_*` constants and `SendTPCM_*` / `SendTPDT` encoders of
/// `NMEA2000.cpp`.
enum ISOTransportProtocol {
  /// Connection management: announcements, requests and replies (`TP_CM`).
  static let connectionManagementPGN: UInt32 = 60416

  /// Data packets (`TP_DT`).
  static let dataTransferPGN: UInt32 = 60160

  /// The priority every transport protocol frame is sent with.
  static let priority: UInt8 = 6

  /// The priority a message received by transport protocol is delivered
  /// with, as the frames don't carry the message's own priority.
  static let receivedPriority: UInt8 = 7

  /// The most packets a receiver asks for in one clear to send
  /// (`TP_MAX_FRAMES`).
  private static let maxPacketsPerClearToSend: UInt8 = 5

  /// How long a sender waits between broadcast data packets, and for the
  /// first clear to send.
  static let packetInterval: UInt64 = 50

  /// How long a sender waits for the next clear to send.
  static let clearToSendTimeout: UInt64 = 100

  /// Connection management control bytes.
  enum Control: UInt8 {
    case requestToSend = 16
    case clearToSend = 17
    case endOfMessageAcknowledgement = 19
    case broadcastAnnounce = 32
    case abort = 255
  }

  /// Why a receiver aborts a session.
  enum AbortReason: UInt8 {
    /// The receiver has no buffer for the message (`TP_CM_AbortBusy`).
    case busy = 1
    /// A data packet arrived out of sequence (`TP_CM_AbortTimeout`).
    case timeout = 3
  }

  /// The number of packets that clear to send asks for: the requested
  /// count, limited to 1…5 (`TPCtsPackets`).
  static func clearToSendPackets(_ requested: UInt8) -> UInt8 {
    max(1, min(requested, maxPacketsPerClearToSend))
  }

  /// The number of data packets a payload needs.
  private static func packetCount(for byteCount: Int) -> UInt8 {
    UInt8(truncatingIfNeeded: (byteCount + 6) / 7)
  }

  /// A connection management message.
  private static func connectionManagement(
    _ control: Control, _ bytes: (UInt8, UInt8, UInt8, UInt8), pgn: UInt32, to destination: UInt8
  ) -> Message {
    Message(
      pgn: connectionManagementPGN, priority: priority, destination: destination,
      data: [
        control.rawValue, bytes.0, bytes.1, bytes.2, bytes.3, UInt8(truncatingIfNeeded: pgn),
        UInt8(truncatingIfNeeded: pgn >> 8), UInt8(truncatingIfNeeded: pgn >> 16),
      ])
  }

  /// The announcement or request that starts sending a message: a BAM to
  /// broadcast it, or a request to send to one device (`SendTPCM_BAM`,
  /// `SendTPCM_RTS`).
  static func start(_ message: Message) -> Message {
    let count = message.data.count
    return connectionManagement(
      message.destination == Message.broadcastAddress ? .broadcastAnnounce : .requestToSend,
      (
        UInt8(truncatingIfNeeded: count), UInt8(truncatingIfNeeded: count >> 8),
        packetCount(for: count), 0xff
      ),
      pgn: message.pgn, to: message.destination)
  }

  /// A clear to send (`SendTPCM_CTS`).
  static func clearToSend(pgn: UInt32, to destination: UInt8, packets: UInt8, next: UInt8)
    -> Message
  {
    connectionManagement(
      .clearToSend, (clearToSendPackets(packets), next, 0xff, 0xff), pgn: pgn, to: destination)
  }

  /// An end of message acknowledgement (`SendTPCM_EndAck`).
  static func endOfMessage(pgn: UInt32, to destination: UInt8, byteCount: Int, packets: UInt8)
    -> Message
  {
    connectionManagement(
      .endOfMessageAcknowledgement,
      (
        UInt8(truncatingIfNeeded: byteCount), UInt8(truncatingIfNeeded: byteCount >> 8), packets,
        0xff
      ),
      pgn: pgn, to: destination)
  }

  /// An abort (`SendTPCM_Abort`).
  static func abort(pgn: UInt32, to destination: UInt8, reason: AbortReason) -> Message {
    connectionManagement(.abort, (reason.rawValue, 0xff, 0xff, 0xff), pgn: pgn, to: destination)
  }

  /// Data packet `index` (from 0) of a message, padded with `0xff`
  /// (`SendTPDT`).
  static func dataPacket(_ index: Int, of message: Message) -> Message {
    let bytes = message.data.dropFirst(index * 7).prefix(7)
    return Message(
      pgn: dataTransferPGN, priority: priority, destination: message.destination,
      data: [UInt8(truncatingIfNeeded: index + 1)] + bytes
        + repeatElement(0xff, count: 7 - bytes.count))
  }
}
