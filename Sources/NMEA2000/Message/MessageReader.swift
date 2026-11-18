// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// A decoder that reads NMEA 2000 fields from a message payload in order.
///
/// Each `read` method ports one of upstream's `tN2kMsg::Get…` helpers with the
/// same width, resolution and "not available" handling, so a `ParseN2kPGN…`
/// body translates line by line. See `docs/field-codec.md` for the full
/// mapping.
///
/// Like upstream, reading past the end of the payload doesn't fail. A scaled
/// or string read returns `nil`, and a raw integer read returns the all-ones
/// "not available" pattern for its width. A read that doesn't fit leaves
/// ``index`` where it was. This lets decoders accept shorter messages from
/// older devices, whose missing trailing fields read as not available.
public struct MessageReader: Sendable {
  /// The payload being read.
  public let data: [UInt8]

  /// The offset of the next byte to read.
  public private(set) var index: Int

  /// Creates a reader positioned at the start of a payload.
  ///
  /// - Parameter data: The payload bytes.
  public init(_ data: [UInt8]) {
    self.data = data
    index = 0
  }

  /// Creates a reader positioned at the start of a message's payload.
  ///
  /// - Parameter message: The message to read.
  public init(_ message: Message) {
    self.init(message.data)
  }

  /// The number of bytes left to read.
  ///
  /// Ports `tN2kMsg::GetRemainingDataLength`.
  public var remainingCount: Int { max(0, data.count - index) }

  /// Moves past bytes without reading them.
  ///
  /// Upstream decoders do this by adding to their index directly. Skipping past
  /// the end stops at the end, and later reads then return not available.
  ///
  /// - Parameter count: The number of bytes to skip. A negative count moves
  ///   back, no further than the start.
  public mutating func skip(_ count: Int) {
    index += min(max(count, -index), data.count - index)
  }

  // MARK: - Integers

  /// Reads one raw byte, or `0xff` past the end.
  ///
  /// Ports `tN2kMsg::GetByte`.
  public mutating func readUInt8() -> UInt8 {
    readLittleEndian(byteCount: 1).map(UInt8.init(truncatingIfNeeded:)) ?? 0xff
  }

  /// Reads a signed 16-bit integer, or `0x7fff` past the end.
  ///
  /// Ports `tN2kMsg::Get2ByteInt`.
  public mutating func readInt16() -> Int16 {
    readLittleEndian(byteCount: 2).map(Int16.init(truncatingIfNeeded:)) ?? 0x7fff
  }

  /// Reads an unsigned 16-bit integer, or `0xffff` past the end.
  ///
  /// Ports `tN2kMsg::Get2ByteUInt`.
  public mutating func readUInt16() -> UInt16 {
    readLittleEndian(byteCount: 2).map(UInt16.init(truncatingIfNeeded:)) ?? 0xffff
  }

  /// Reads an unsigned 24-bit integer, or `0xffffffff` past the end.
  ///
  /// Ports `tN2kMsg::Get3ByteUInt`. Note that the past-the-end value is 32 bits
  /// wide, as upstream's is.
  public mutating func readUInt24() -> UInt32 {
    readLittleEndian(byteCount: 3).map(UInt32.init(truncatingIfNeeded:)) ?? 0xffff_ffff
  }

  /// Reads an unsigned 32-bit integer, or `0xffffffff` past the end.
  ///
  /// Ports `tN2kMsg::Get4ByteUInt`.
  public mutating func readUInt32() -> UInt32 {
    readLittleEndian(byteCount: 4).map(UInt32.init(truncatingIfNeeded:)) ?? 0xffff_ffff
  }

  /// Reads an unsigned 64-bit integer, or all ones past the end.
  ///
  /// Ports `tN2kMsg::GetUInt64`.
  public mutating func readUInt64() -> UInt64 {
    readLittleEndian(byteCount: 8) ?? .max
  }

  // MARK: - Optional integers

  /// Reads a byte, or `nil` if it is `0xff` (not available) or past the end.
  public mutating func readOptionalUInt8() -> UInt8? {
    let value = readUInt8()
    return value == .max ? nil : value
  }

  /// Reads a signed byte, or `nil` if it is `0x7f` (not available) or past
  /// the end.
  ///
  /// Upstream reads these with `GetByte`, which returns `0xff` (-1) past the
  /// end; this method returns `nil` instead.
  public mutating func readOptionalInt8() -> Int8? {
    guard remainingCount >= 1 else { return nil }
    let value = Int8(bitPattern: readUInt8())
    return value == .max ? nil : value
  }

  /// Reads a signed 16-bit integer, or `nil` if it is `0x7fff` (not
  /// available) or past the end.
  public mutating func readOptionalInt16() -> Int16? {
    let value = readInt16()
    return value == .max ? nil : value
  }

  /// Reads an unsigned 16-bit integer, or `nil` if it is `0xffff` (not
  /// available) or past the end.
  public mutating func readOptionalUInt16() -> UInt16? {
    let value = readUInt16()
    return value == .max ? nil : value
  }

  /// Reads an unsigned 32-bit integer, or `nil` if it is `0xffffffff` (not
  /// available) or past the end.
  public mutating func readOptionalUInt32() -> UInt32? {
    let value = readUInt32()
    return value == .max ? nil : value
  }

  // MARK: - Scaled values

  /// Reads a signed 8-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get1ByteDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0x7f`) or past
  ///   the end.
  public mutating func readInt8(resolution: Double) -> Double? {
    readScaled(byteCount: 1, resolution: resolution, notAvailable: 0x7f) {
      Int64(Int8(truncatingIfNeeded: $0))
    }
  }

  /// Reads an unsigned 8-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get1ByteUDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0xff`) or past
  ///   the end.
  public mutating func readUInt8(resolution: Double) -> Double? {
    readScaled(byteCount: 1, resolution: resolution, notAvailable: 0xff) { Int64($0) }
  }

  /// Reads a signed 16-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get2ByteDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0x7fff`) or past
  ///   the end.
  public mutating func readInt16(resolution: Double) -> Double? {
    readScaled(byteCount: 2, resolution: resolution, notAvailable: 0x7fff) {
      Int64(Int16(truncatingIfNeeded: $0))
    }
  }

  /// Reads an unsigned 16-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get2ByteUDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0xffff`) or past
  ///   the end.
  public mutating func readUInt16(resolution: Double) -> Double? {
    readScaled(byteCount: 2, resolution: resolution, notAvailable: 0xffff) { Int64($0) }
  }

  /// Reads a signed 24-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get3ByteDouble`, with one deliberate fix: upstream
  /// doesn't sign-extend the 24-bit value, so it decodes negative values as
  /// large positive ones. This method sign-extends.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0x7fffff`) or
  ///   past the end.
  public mutating func readInt24(resolution: Double) -> Double? {
    readScaled(byteCount: 3, resolution: resolution, notAvailable: 0x7f_ffff) {
      Int64(Int32(truncatingIfNeeded: $0 << 8) >> 8)
    }
  }

  /// Reads an unsigned 24-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get3ByteUDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0xffffff`) or
  ///   past the end.
  public mutating func readUInt24(resolution: Double) -> Double? {
    readScaled(byteCount: 3, resolution: resolution, notAvailable: 0xff_ffff) { Int64($0) }
  }

  /// Reads a signed 32-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get4ByteDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0x7fffffff`) or
  ///   past the end.
  public mutating func readInt32(resolution: Double) -> Double? {
    readScaled(byteCount: 4, resolution: resolution, notAvailable: 0x7fff_ffff) {
      Int64(Int32(truncatingIfNeeded: $0))
    }
  }

  /// Reads an unsigned 32-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get4ByteUDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available (`0xffffffff`) or
  ///   past the end.
  public mutating func readUInt32(resolution: Double) -> Double? {
    readScaled(byteCount: 4, resolution: resolution, notAvailable: 0xffff_ffff) { Int64($0) }
  }

  /// Reads a signed 64-bit field and scales it.
  ///
  /// Ports `tN2kMsg::Get8ByteDouble`.
  ///
  /// - Parameter resolution: The value of one least significant bit.
  /// - Returns: The value, or `nil` if it is not available
  ///   (`0x7fffffffffffffff`) or past the end.
  public mutating func readInt64(resolution: Double) -> Double? {
    readScaled(
      byteCount: 8, resolution: resolution, notAvailable: 0x7fff_ffff_ffff_ffff
    ) { Int64(bitPattern: $0) }
  }

  /// Reads a 32-bit IEEE 754 floating-point value.
  ///
  /// Ports `tN2kMsg::GetFloat`.
  ///
  /// - Returns: The value, or `nil` if it is not available (`0x7fffffff`), is
  ///   NaN, or is past the end.
  public mutating func readFloat32() -> Float? {
    guard let bits = readLittleEndian(byteCount: 4), bits != 0x7fff_ffff else { return nil }
    let value = Float(bitPattern: UInt32(truncatingIfNeeded: bits))
    return value.isNaN ? nil : value
  }

  // MARK: - Strings and bytes

  /// Reads a fixed-length string field.
  ///
  /// Ports `tN2kMsg::GetStr`. The string ends at the first NUL or
  /// `terminator` byte, but the whole field is consumed. Bytes that aren't
  /// valid UTF-8 are replaced with U+FFFD.
  ///
  /// - Parameters:
  ///   - count: The field width, in bytes.
  ///   - terminator: A padding byte that also ends the string. Upstream uses
  ///     `0xff` for most fields and `@` (`0x40`) for AIS fields.
  /// - Returns: The string, or `nil` if the field runs past the end. In that
  ///   case ``index`` doesn't move.
  public mutating func readFixedString(count: Int, terminator: UInt8 = 0xff) -> String? {
    guard count >= 0, index + count <= data.count else { return nil }
    let field = data[index..<index + count]
    index += count
    return Self.decodeString(field.prefix { $0 != 0 && $0 != terminator })
  }

  /// Reads a variable-length string field.
  ///
  /// Ports `tN2kMsg::GetVarStr`. Both ASCII (encoding byte `1`) and UCS-2
  /// (encoding byte `0`) fields are decoded. A field whose declared length runs
  /// past the end of the payload is truncated, as upstream truncates it.
  ///
  /// - Parameter terminator: A padding byte that also ends an ASCII string,
  ///   and that is dropped from a UCS-2 string when it is below `0x80`.
  /// - Returns: The string, or `nil` if the field header is invalid. In that
  ///   case the rest of the payload is skipped, as upstream does.
  public mutating func readVariableString(terminator: UInt8 = 0xff) -> String? {
    let length = readUInt8()
    let type = readUInt8()
    if length <= 2 || length == 0xff || type > 1 || index >= data.count {
      if length == 2 && type <= 1 { return "" }
      index = max(index, data.count)
      return nil
    }
    let count = min(Int(length) - 2, data.count - index)
    let field = data[index..<index + count]
    index += count
    if type == 1 {
      return Self.decodeString(field.prefix { $0 != 0 && $0 != terminator })
    }
    return Self.decodeUCS2(field, terminator: terminator)
  }

  /// Reads raw bytes.
  ///
  /// Ports `tN2kMsg::GetBuf`. Upstream doesn't advance its index when it
  /// copies into a buffer; this method always advances past the bytes it
  /// returns.
  ///
  /// - Parameter count: The number of bytes to read.
  /// - Returns: The bytes, or `nil` if they run past the end. In that case the
  ///   rest of the payload is skipped, as upstream does.
  public mutating func readBytes(count: Int) -> [UInt8]? {
    guard count >= 0, index + count <= data.count else {
      index = max(index, data.count)
      return nil
    }
    defer { index += count }
    return Array(data[index..<index + count])
  }

  // MARK: - Private

  private mutating func readLittleEndian(byteCount: Int) -> UInt64? {
    guard index >= 0, index + byteCount <= data.count else { return nil }
    var value: UInt64 = 0
    for offset in 0..<byteCount {
      value |= UInt64(data[index + offset]) << (8 * offset)
    }
    index += byteCount
    return value
  }

  private mutating func readScaled(
    byteCount: Int,
    resolution: Double,
    notAvailable: UInt64,
    signed: (UInt64) -> Int64
  ) -> Double? {
    guard let raw = readLittleEndian(byteCount: byteCount), raw != notAvailable else {
      return nil
    }
    return Double(signed(raw)) * resolution
  }

  private static func decodeString(_ bytes: some Collection<UInt8>) -> String {
    String(decoding: bytes, as: UTF8.self)
  }

  /// Ports upstream's `N2kUCS2ToUTF8`. Upstream produces a C string, so a NUL
  /// character ends it.
  private static func decodeUCS2(_ bytes: ArraySlice<UInt8>, terminator: UInt8) -> String {
    var scalars = String.UnicodeScalarView()
    var i = bytes.startIndex
    while i + 1 < bytes.endIndex {
      let unit = UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8
      i += 2
      if unit == 0 { break }
      if unit < 0x80 && unit == terminator { continue }
      scalars.append(Unicode.Scalar(unit) ?? "\u{FFFD}")
    }
    return String(scalars)
  }
}
