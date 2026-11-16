// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

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
