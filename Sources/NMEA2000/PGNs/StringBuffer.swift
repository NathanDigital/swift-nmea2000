// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

extension String {
  /// The longest prefix of whole characters that fits in a fixed C string
  /// buffer of `byteCount` UTF-8 bytes.
  ///
  /// Upstream keeps some strings in fixed `char` arrays filled with `strncpy`,
  /// which truncates by bytes before the string is encoded. This reproduces
  /// that limit. Where `strncpy` would cut a character in half, this stops at
  /// the character before instead.
  func prefix(utf8ByteCount byteCount: Int) -> String {
    var used = 0
    var scalars = String.UnicodeScalarView()
    for scalar in unicodeScalars {
      let size = String(scalar).utf8.count
      guard used + size <= byteCount else { break }
      scalars.append(scalar)
      used += size
    }
    return String(scalars)
  }
}
