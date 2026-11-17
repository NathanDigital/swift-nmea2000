// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

extension Optional where Wrapped == Double {
  /// Whether both values are `nil`, or both are present and within
  /// `tolerance` of each other.
  func isApproximatelyEqual(to other: Double?, tolerance: Double) -> Bool {
    switch (self, other) {
    case (nil, nil): true
    case (let lhs?, let rhs?): abs(lhs - rhs) <= tolerance
    default: false
    }
  }
}

/// Checks that a value encodes to the bytes upstream produces, with
/// upstream's PGN and priority.
func expectEncodes<P: ParameterGroup>(
  _ value: P, as bytes: [UInt8], priority: UInt8,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  let message = value.makeMessage()
  #expect(message.pgn == P.pgn, sourceLocation: sourceLocation)
  #expect(message.priority == priority, sourceLocation: sourceLocation)
  #expect(message.data == bytes, sourceLocation: sourceLocation)
}

/// Checks that upstream's bytes decode, and that the decoded value encodes
/// back to the same bytes.
func expectDecodes<P: ParameterGroup>(
  _ type: P.Type, from bytes: [UInt8],
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let decoded = try P(Message(pgn: P.pgn, data: bytes))
  #expect(decoded.makeMessage().data == bytes, sourceLocation: sourceLocation)
}

/// Checks the decoding behaviour every parameter group shares: every prefix
/// of a valid payload decodes without throwing, as upstream tolerates short
/// messages, and a message with another PGN is rejected.
func expectTolerantDecoding<P: ParameterGroup>(
  _ type: P.Type, from bytes: [UInt8],
  sourceLocation: SourceLocation = #_sourceLocation
) {
  for count in 0...bytes.count {
    #expect(throws: Never.self, "prefix of \(count) bytes", sourceLocation: sourceLocation) {
      _ = try P(Message(pgn: P.pgn, data: Array(bytes.prefix(count))))
    }
  }
  #expect(
    throws: MessageDecodingError.unexpectedPGN(expected: P.pgn, actual: P.pgn + 1),
    sourceLocation: sourceLocation
  ) {
    _ = try P(Message(pgn: P.pgn + 1, data: bytes))
  }
}
