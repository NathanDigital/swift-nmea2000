// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

extension Node {
  /// An ISO request for a PGN the node doesn't answer itself.
  public struct PGNRequest: Sendable, Hashable {
    /// The PGN asked for.
    public var pgn: UInt32
    /// The requester's address.
    public var requester: UInt8
    /// The node's device the request is for.
    public var device: DeviceID
    /// Whether the request was broadcast, so that every device is asked in
    /// turn and none answers with a negative acknowledgement.
    public var isBroadcast: Bool

    /// Creates a request.
    public init(pgn: UInt32, requester: UInt8, device: DeviceID, isBroadcast: Bool) {
      self.pgn = pgn
      self.requester = requester
      self.device = device
      self.isBroadcast = isBroadcast
    }
  }

  /// Answers an ISO request for a PGN the node doesn't answer itself.
  ///
  /// The handler returns the messages the device sends in reply, or `nil`
  /// if it doesn't handle the PGN; the device then sends a negative
  /// acknowledgement if the request was addressed to it.
  ///
  /// Handlers are synchronous because the node answers while it handles
  /// the request's frame, before the next one, as upstream does; an
  /// `await` there would let other frames through first. Keep what a
  /// handler needs where it can read it at once, such as in a
  /// `Mutex`-protected value that the rest of the app updates.
  ///
  /// Replaces upstream's `SetISORqstHandler` callback.
  public typealias ISORequestHandler = @Sendable (PGNRequest) -> [Message]?

  /// Answers group functions (PGN 126208) for a PGN, as an upstream
  /// `tN2kGroupFunctionHandler` subclass does.
  ///
  /// The handler gets the request and returns the messages its device sends
  /// in reply, usually a ``GroupFunction/Acknowledgement`` or a
  /// ``GroupFunction/Reply``, or `nil` to let the node answer as it does
  /// without a handler, which upstream's subclasses get by calling the base
  /// class. The handler sees broadcast commands, reads and writes too,
  /// which upstream ignores. Like ``ISORequestHandler``, it's synchronous.
  public typealias GroupFunctionHandler = @Sendable (GroupFunction.ReceivedFunction) -> [Message]?
}
