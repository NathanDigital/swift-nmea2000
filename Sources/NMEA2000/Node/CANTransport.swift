// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A connection to a CAN bus that sends and receives extended (29-bit) CAN
/// frames, which a ``Node`` runs on.
///
/// Implement it for your CAN hardware or operating system interface (such as
/// SocketCAN), or for a gateway that carries raw frames. The bus must run at
/// 250 kbit/s, the NMEA 2000 bit rate.
///
/// Replaces upstream's `CANOpen`, `CANSendFrame` and `CANGetFrame` virtual
/// functions, which each CAN driver class overrides.
public protocol CANTransport: Sendable {
  /// The frames the transport receives.
  associatedtype Frames: AsyncSequence, Sendable where Frames.Element == CANFrame

  /// Opens the connection, and returns the frames it receives from then on.
  ///
  /// The node calls this once, and again a second later each time it
  /// throws. The sequence should end when the connection closes.
  ///
  /// - Throws: Any error that stopped the connection opening.
  func open() async throws -> Frames

  /// Sends a frame, suspending while the transmit queue is full.
  ///
  /// The node sends one message's frames in order, and doesn't send another
  /// message's frames until they're done.
  ///
  /// - Throws: Any error that stopped the frame being sent.
  func send(_ frame: CANFrame) async throws
}
