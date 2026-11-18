// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Why a node can't send a message.
public enum NodeError: Error, Sendable, Hashable {
  /// The node isn't running, or is still opening its transport.
  case notOpen
  /// ``Node/run()`` was called while the node was already running.
  case alreadyRunning
  /// The node is in ``Node/Mode/listenOnly`` mode.
  case listenOnly
  /// The node is claiming its address. Try again once the claim is done,
  /// 250 ms after it started.
  case claimingAddress
  /// Every address was taken, so the node has none.
  case noAddress
  /// A message is already being sent by transport protocol, which sends one
  /// message at a time.
  case transferInProgress
  /// Only a node in ``Node/Mode/node`` mode can send by transport protocol.
  case notAFullNode
  /// The node has no device with this index.
  case noSuchDevice(Node.DeviceID)
  /// The message can't be framed.
  case invalidMessage(FramingError)
}

extension NodeError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .notOpen: "The node isn't open"
    case .alreadyRunning: "The node is already running"
    case .listenOnly: "A listen-only node can't send"
    case .claimingAddress: "The node is still claiming its address"
    case .noAddress: "The node found no free address"
    case .transferInProgress: "A transport protocol transfer is already in progress"
    case .notAFullNode: "Only a full node can send by transport protocol"
    case .noSuchDevice(let device): "The node has no \(device)"
    case .invalidMessage(let error): "The message can't be framed: \(error)"
    }
  }
}
