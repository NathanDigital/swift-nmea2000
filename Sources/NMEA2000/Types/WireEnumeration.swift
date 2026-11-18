// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A field whose values upstream lists in an enum, kept open so that values
/// from newer devices survive.
///
/// A conforming type is a struct around the value as it appears on the
/// wire, with a static constant for each value upstream names. Unlike a
/// Swift `enum`, it holds any raw value: one without a name decodes, compares
/// and re-encodes unchanged, and describes itself as `unknown (n)`.
///
/// ```swift
/// let reference = WindReference(rawValue: 2)  // .apparent
/// let future = WindReference(rawValue: 7)     // kept, though it has no name
/// ```
///
/// `Codable` encodes the raw value alone.
public protocol WireEnumeration: RawRepresentable, Codable, Hashable, Sendable,
  CustomStringConvertible
where RawValue: FixedWidthInteger & Codable & Sendable {
  /// Creates a value from its wire representation. Every raw value is
  /// accepted.
  init(rawValue: RawValue)
}
