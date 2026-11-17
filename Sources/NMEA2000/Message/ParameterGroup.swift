// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The decoded contents of a message with a particular PGN.
///
/// Each conforming type ports one upstream `SetN2kPGN…` / `ParseN2kPGN…` pair.
/// ``encode(into:)`` is a line-by-line translation of the `Set` body and
/// ``init(decoding:)`` of the `Parse` body, in the same field order, using the
/// ``MessageWriter`` and ``MessageReader`` equivalents of upstream's helpers.
///
/// Create a message to send with ``makeMessage(priority:destination:)``, and
/// decode a received one with ``init(_:)``:
///
/// ```swift
/// let message = PositionRapidUpdate(latitude: 60.15, longitude: 24.95).makeMessage()
/// let position = try PositionRapidUpdate(message)
/// ```
///
/// Every parameter group is `Hashable` and `Codable`, so it can be compared,
/// stored, or logged as JSON. `Codable` encodes the Swift properties, not the
/// wire format; use ``makeMessage(priority:destination:)`` for that.
public protocol ParameterGroup: Sendable, Hashable, Codable {
  /// The parameter group number this type encodes and decodes.
  static var pgn: UInt32 { get }

  /// The priority upstream assigns when it sends this parameter group.
  static var defaultPriority: UInt8 { get }

  /// Decodes the fields from a payload.
  ///
  /// Implementations read fields in wire order and don't check the PGN;
  /// ``init(_:)`` does that. Like upstream, they accept a payload shorter
  /// than the full field list, and the missing fields decode as not available.
  /// They ignore any bytes after the fields they know.
  ///
  /// - Parameter reader: A reader positioned at the start of the fields.
  /// - Throws: ``MessageDecodingError`` if the payload is invalid in a way
  ///   upstream also rejects.
  init(decoding reader: inout MessageReader) throws(MessageDecodingError)

  /// Encodes the fields into a payload.
  ///
  /// - Parameter writer: The writer to append the fields to.
  func encode(into writer: inout MessageWriter)
}

extension ParameterGroup {
  /// Decodes a received message.
  ///
  /// - Parameter message: The message to decode.
  /// - Throws: ``MessageDecodingError/unexpectedPGN(actual:expected:)`` if the
  ///   message has a different PGN, or any error from ``init(decoding:)``.
  public init(_ message: Message) throws(MessageDecodingError) {
    guard message.pgn == Self.pgn else {
      throw .unexpectedPGN(actual: message.pgn, expected: [Self.pgn])
    }
    var reader = MessageReader(message)
    try self.init(decoding: &reader)
  }

  /// Encodes the parameter group as a message ready to send.
  ///
  /// The source address is left at its default; the node sets it when it
  /// sends the message.
  ///
  /// - Parameters:
  ///   - priority: The priority, or `nil` for ``defaultPriority``.
  ///   - destination: The destination address. Most parameter groups are
  ///     broadcast.
  /// - Returns: The message.
  public func makeMessage(
    priority: UInt8? = nil,
    destination: UInt8 = Message.broadcastAddress
  ) -> Message {
    var writer = MessageWriter()
    encode(into: &writer)
    return Message(
      pgn: Self.pgn,
      priority: priority ?? Self.defaultPriority,
      destination: destination,
      data: writer.data)
  }
}

/// An error that occurs when a message can't be decoded.
public enum MessageDecodingError: Error, Hashable, Sendable {
  /// The message's PGN isn't one the decoding type handles.
  case unexpectedPGN(actual: UInt32, expected: [UInt32])

  /// The payload's length is outside the range upstream accepts.
  case invalidLength(pgn: UInt32, count: Int, allowed: ClosedRange<Int>)

  /// A proprietary message doesn't start with the manufacturer and industry
  /// code the decoding type expects.
  case unexpectedProprietaryHeader(pgn: UInt32, header: UInt16, expected: UInt16)

  /// A proprietary message carries a kind of record the decoding type
  /// doesn't handle.
  case unexpectedRecord(pgn: UInt32, identifier: UInt8)
}

extension MessageDecodingError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unexpectedPGN(let actual, let expected):
      "PGN \(actual) isn't \(expected.map(String.init).joined(separator: " or "))"
    case .invalidLength(let pgn, let count, let allowed):
      "PGN \(pgn) payload of \(count) bytes isn't \(allowed.lowerBound) to \(allowed.upperBound) bytes"
    case .unexpectedProprietaryHeader(let pgn, let header, let expected):
      "PGN \(pgn) header 0x\(String(header, radix: 16)) isn't 0x\(String(expected, radix: 16))"
    case .unexpectedRecord(let pgn, let identifier):
      "PGN \(pgn) record 0x\(String(identifier, radix: 16)) isn't supported"
    }
  }
}
