// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A clock reduced to what the node needs: milliseconds since the node was
/// created, and sleeping until a given millisecond.
struct NodeClock: Sendable {
  let now: @Sendable () -> UInt64
  let sleep: @Sendable (_ until: UInt64) async throws -> Void

  init<C: Clock>(_ clock: C) where C.Duration == Duration {
    let start = clock.now
    now = { start.duration(to: clock.now).wholeMilliseconds }
    sleep = { milliseconds in
      try await clock.sleep(until: start.advanced(by: .milliseconds(milliseconds)), tolerance: nil)
    }
  }
}
