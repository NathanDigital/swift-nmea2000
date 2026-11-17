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

/// Checks that upstream's bytes decode to the value they were encoded from,
/// and that the decoded value encodes back to the same bytes.
///
/// The value comparison walks both values' stored properties by reflection.
/// Everything must match exactly except `Double`s, which only need to agree
/// to within 0.5% or 0.05, whichever is larger, because encoding rounds them
/// to the field's resolution. The re-encode check already pins doubles to
/// upstream's bytes. The value check catches decode errors that the encoder
/// would mask away again, such as a flag read from the wrong bit.
///
/// When encoding loses information (text is truncated or upper-cased, a
/// field is masked, a list is capped), pass what the bytes decode to as
/// `expected`, not the value that was encoded.
func expectDecodes<P: ParameterGroup>(
  _ bytes: [UInt8], as expected: P,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let decoded = try P(Message(pgn: P.pgn, data: bytes))
  #expect(decoded.makeMessage().data == bytes, sourceLocation: sourceLocation)
  let differences = differences(between: decoded, and: expected, at: "\(P.self)")
  #expect(
    differences.isEmpty, "decoded value differs: \(differences.joined(separator: "; "))",
    sourceLocation: sourceLocation)
}

/// The paths at which two values differ, compared through reflection.
private func differences(between actual: Any, and expected: Any, at path: String) -> [String] {
  let actualMirror = Mirror(reflecting: actual)
  let expectedMirror = Mirror(reflecting: expected)
  if actualMirror.displayStyle == .optional || expectedMirror.displayStyle == .optional {
    switch (actualMirror.children.first, expectedMirror.children.first) {
    case (nil, nil): return []
    case (let lhs?, let rhs?): return differences(between: lhs.value, and: rhs.value, at: path)
    case (nil, _?): return ["\(path) is nil, expected \(expected)"]
    case (_?, nil): return ["\(path) is \(actual), expected nil"]
    }
  }
  if let lhs = actual as? Double, let rhs = expected as? Double {
    let tolerance = max(abs(rhs) * 0.005, 0.05) + 1e-9
    return abs(lhs - rhs) <= tolerance ? [] : ["\(path) is \(lhs), expected \(rhs)"]
  }
  let actualChildren = Array(actualMirror.children)
  let expectedChildren = Array(expectedMirror.children)
  if actualChildren.isEmpty && expectedChildren.isEmpty {
    let lhs = String(describing: actual)
    let rhs = String(describing: expected)
    return lhs == rhs ? [] : ["\(path) is \(lhs), expected \(rhs)"]
  }
  guard actualChildren.count == expectedChildren.count else {
    return ["\(path) has \(actualChildren.count) elements, expected \(expectedChildren.count)"]
  }
  var result: [String] = []
  for (index, (lhs, rhs)) in zip(actualChildren, expectedChildren).enumerated() {
    guard lhs.label == rhs.label else {
      return ["\(path) is \(actual), expected \(expected)"]
    }
    let child = lhs.label.map { "\(path).\($0)" } ?? "\(path)[\(index)]"
    result += differences(between: lhs.value, and: rhs.value, at: child)
  }
  return result
}

/// A copy of `value` with `change` applied, for writing what a vector
/// decodes to when it differs from the encoded value in a few fields.
func with<T>(_ value: T, _ change: (inout T) -> Void) -> T {
  var copy = value
  change(&copy)
  return copy
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
    throws: MessageDecodingError.unexpectedPGN(actual: P.pgn + 1, expected: [P.pgn]),
    sourceLocation: sourceLocation
  ) {
    _ = try P(Message(pgn: P.pgn + 1, data: bytes))
  }
}
