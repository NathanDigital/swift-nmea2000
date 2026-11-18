// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Whether `first` is before `second` on a wrapping millisecond clock
/// (upstream's `N2kIsTimeBefore`, which also counts equal times).
func isTime(_ first: UInt32, before second: UInt32) -> Bool {
  second &- first < UInt32(Int32.max)
}

/// Whether `interval` milliseconds have passed since `start` at time `now`
/// on a wrapping millisecond clock (upstream's `N2kHasElapsed`).
func hasElapsed(_ interval: UInt32, since start: UInt32, at now: UInt32) -> Bool {
  now &- (start &+ interval) < UInt32(Int32.max)
}

extension Duration {
  /// The duration in whole milliseconds, wrapped to 32 bits like upstream's
  /// `millis()`, for its wrapping time comparisons and for the gateway
  /// formats' 32-bit time stamps.
  var wrappingMilliseconds: UInt32 {
    let (seconds, attoseconds) = components
    return UInt32(truncatingIfNeeded: seconds &* 1000 &+ attoseconds / 1_000_000_000_000_000)
  }

  /// The duration in whole milliseconds, or 0 if it's negative, for the
  /// node's millisecond clock.
  var wholeMilliseconds: UInt64 {
    let (seconds, attoseconds) = components
    guard seconds >= 0 else { return 0 }
    return UInt64(seconds) * 1000 + UInt64(attoseconds / 1_000_000_000_000_000)
  }
}
