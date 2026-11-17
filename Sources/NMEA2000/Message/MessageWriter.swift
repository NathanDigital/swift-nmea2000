// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// An encoder that appends NMEA 2000 fields to a message payload.
///
/// Each `append` method ports one of upstream's `tN2kMsg::Add…` helpers with
/// the same width, resolution, rounding and "not available" encoding, so a
/// `SetN2kPGN…` body translates line by line. See `docs/field-codec.md` for
/// the full mapping.
///
/// Multi-byte values are little-endian. Scaled values are divided by their
/// resolution and rounded half away from zero, as upstream does. A `nil` value
/// writes the field's "not available" pattern. A value outside the field's
/// range writes its "out of range" pattern.
///
/// Fixed-width fields must fit in the remaining capacity. Writing past
/// ``Message/maxDataCount`` is a programming error and traps. String and byte
/// fields that upstream truncates to the capacity are truncated the same way.
public struct MessageWriter: Sendable {
  /// The bytes written so far.
  public private(set) var data: [UInt8]

  /// Creates an empty writer.
  public init() {
    data = []
    data.reserveCapacity(8)
  }

  /// The number of bytes written so far.
  ///
  /// Use it to remember a field's position for a later ``setUInt8(_:at:)`` or
  /// ``setUInt16(_:at:)``.
  public var count: Int { data.count }

  /// The number of bytes that can still be written.
  ///
  /// Ports `tN2kMsg::GetAvailableDataLength`.
  public var availableCount: Int { Message.maxDataCount - data.count }

  // MARK: - Integers

  /// Appends one raw byte.
  ///
  /// Ports `tN2kMsg::AddByte`.
  public mutating func appendUInt8(_ value: UInt8) {
    appendLittleEndian(value, byteCount: 1)
  }

  /// Appends a signed 16-bit integer.
  ///
  /// Ports `tN2kMsg::Add2ByteInt`.
  public mutating func appendInt16(_ value: Int16) {
    appendLittleEndian(value, byteCount: 2)
  }

  /// Appends an unsigned 16-bit integer.
  ///
  /// Ports `tN2kMsg::Add2ByteUInt`.
  public mutating func appendUInt16(_ value: UInt16) {
    appendLittleEndian(value, byteCount: 2)
  }

  /// Appends the low 24 bits of a signed integer.
  ///
  /// Ports `tN2kMsg::Add3ByteInt`.
  public mutating func appendInt24(_ value: Int32) {
    appendLittleEndian(value, byteCount: 3)
  }

  /// Appends an unsigned 32-bit integer.
  ///
  /// Ports `tN2kMsg::Add4ByteUInt`.
  public mutating func appendUInt32(_ value: UInt32) {
    appendLittleEndian(value, byteCount: 4)
  }

  /// Appends an unsigned 64-bit integer.
  ///
  /// Ports `tN2kMsg::AddUInt64`.
  public mutating func appendUInt64(_ value: UInt64) {
    appendLittleEndian(value, byteCount: 8)
  }

  // MARK: - Optional integers

  /// Appends a byte, or `0xff` if it is not available.
  ///
  /// Upstream passes `N2kUInt8NA` to `AddByte` for a missing value.
  public mutating func appendUInt8(_ value: UInt8?) {
    appendUInt8(value ?? .max)
  }

  /// Appends a signed byte, or `0x7f` if it is not available.
  ///
  /// Upstream passes an `int8_t` to `AddByte`, with `N2kInt8NA` for a missing
  /// value.
  public mutating func appendInt8(_ value: Int8?) {
    appendLittleEndian(value ?? .max, byteCount: 1)
  }

  /// Appends a signed 16-bit integer, or `0x7fff` if it is not available.
  ///
  /// Upstream passes `N2kInt16NA` to `Add2ByteInt` for a missing value.
  public mutating func appendInt16(_ value: Int16?) {
    appendInt16(value ?? .max)
  }

  /// Appends an unsigned 16-bit integer, or `0xffff` if it is not available.
  ///
  /// Upstream passes `N2kUInt16NA` to `Add2ByteUInt` for a missing value.
  public mutating func appendUInt16(_ value: UInt16?) {
    appendUInt16(value ?? .max)
  }

  /// Appends an unsigned 32-bit integer, or `0xffffffff` if it is not
  /// available.
  ///
  /// Upstream passes `N2kUInt32NA` to `Add4ByteUInt` for a missing value.
  public mutating func appendUInt32(_ value: UInt32?) {
    appendUInt32(value ?? .max)
  }

  // MARK: - Scaled values

  /// Appends a value scaled into a signed 8-bit field.
  ///
  /// Ports `tN2kMsg::Add1ByteDouble`. Not available is `0x7f`; out of range is
  /// `0x7e`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendInt8(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(Int8.max, byteCount: 1) }
    let scaled = Self.scale(value, resolution)
    let raw: Int8 = scaled >= -128 && scaled < 0x7e ? Int8(scaled) : 0x7e
    appendLittleEndian(raw, byteCount: 1)
  }

  /// Appends a value scaled into an unsigned 8-bit field.
  ///
  /// Ports `tN2kMsg::Add1ByteUDouble`. Not available is `0xff`; out of range,
  /// including any negative value, is `0xfe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendUInt8(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(UInt8.max, byteCount: 1) }
    let scaled = Self.scale(value, resolution)
    let raw: UInt8 = scaled >= 0 && scaled < 0xfe ? UInt8(scaled) : 0xfe
    appendLittleEndian(raw, byteCount: 1)
  }

  /// Appends a value scaled into a signed 16-bit field.
  ///
  /// Ports `tN2kMsg::Add2ByteDouble`. Not available is `0x7fff`; out of range
  /// is `0x7ffe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendInt16(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(Int16.max, byteCount: 2) }
    let scaled = Self.scale(value, resolution)
    let raw: Int16 = scaled >= -32768 && scaled < 0x7ffe ? Int16(scaled) : 0x7ffe
    appendLittleEndian(raw, byteCount: 2)
  }

  /// Appends a value scaled into an unsigned 16-bit field.
  ///
  /// Ports `tN2kMsg::Add2ByteUDouble`. Not available is `0xffff`; out of
  /// range, including any negative value, is `0xfffe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendUInt16(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(UInt16.max, byteCount: 2) }
    let scaled = Self.scale(value, resolution)
    let raw: UInt16 = scaled >= 0 && scaled < 0xfffe ? UInt16(scaled) : 0xfffe
    appendLittleEndian(raw, byteCount: 2)
  }

  /// Appends a value scaled into a signed 24-bit field.
  ///
  /// Ports `tN2kMsg::Add3ByteDouble`. Not available is `0x7fffff`; out of
  /// range is `0x7ffffe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendInt24(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(Int32(0x7f_ffff), byteCount: 3) }
    let scaled = Self.scale(value, resolution)
    let raw: Int32 = scaled >= -8_388_608 && scaled < 0x7f_fffe ? Int32(scaled) : 0x7f_fffe
    appendLittleEndian(raw, byteCount: 3)
  }

  /// Appends a value scaled into an unsigned 24-bit field.
  ///
  /// Ports `tN2kMsg::Add3ByteUDouble`. Not available is `0xffffff`; out of
  /// range, including any negative value, is `0xfffffe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendUInt24(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(UInt32(0xff_ffff), byteCount: 3) }
    let scaled = Self.scale(value, resolution)
    let raw: UInt32 = scaled >= 0 && scaled < 0xff_fffe ? UInt32(scaled) : 0xff_fffe
    appendLittleEndian(raw, byteCount: 3)
  }

  /// Appends a value scaled into a signed 32-bit field.
  ///
  /// Ports `tN2kMsg::Add4ByteDouble`. Not available is `0x7fffffff`; out of
  /// range is `0x7ffffffe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendInt32(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(Int32.max, byteCount: 4) }
    let scaled = Self.scale(value, resolution)
    let raw: Int32 =
      scaled >= -2_147_483_648 && scaled < 0x7fff_fffe ? Int32(scaled) : 0x7fff_fffe
    appendLittleEndian(raw, byteCount: 4)
  }

  /// Appends a value scaled into an unsigned 32-bit field.
  ///
  /// Ports `tN2kMsg::Add4ByteUDouble`. Not available is `0xffffffff`; out of
  /// range, including any negative value, is `0xfffffffe`.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendUInt32(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(UInt32.max, byteCount: 4) }
    let scaled = Self.scale(value, resolution)
    let raw: UInt32 = scaled >= 0 && scaled < 0xffff_fffe ? UInt32(scaled) : 0xffff_fffe
    appendLittleEndian(raw, byteCount: 4)
  }

  /// Appends a value scaled into a signed 64-bit field.
  ///
  /// Ports `tN2kMsg::Add8ByteDouble`. Unlike the narrower fields, upstream
  /// truncates toward zero here instead of rounding, and this method does the
  /// same. Not available is `0x7fffffffffffffff`.
  ///
  /// Upstream has no out-of-range handling for this width (the conversion is
  /// undefined behaviour in C++). This method writes `0x7ffffffffffffffe` for
  /// a value that doesn't fit, by analogy with the narrower fields.
  ///
  /// - Parameters:
  ///   - value: The value, or `nil` if not available.
  ///   - resolution: The value of one least significant bit.
  public mutating func appendInt64(_ value: Double?, resolution: Double) {
    guard let value else { return appendLittleEndian(Int64.max, byteCount: 8) }
    let scaled = (value / resolution).rounded(.towardZero)
    // 2^63 is the first double above Int64.max.
    let raw: Int64 =
      scaled >= -9_223_372_036_854_775_808.0 && scaled < 9_223_372_036_854_775_808.0
      ? Int64(scaled) : 0x7fff_ffff_ffff_fffe
    appendLittleEndian(raw, byteCount: 8)
  }

  /// Appends a 32-bit IEEE 754 floating-point value.
  ///
  /// Ports `tN2kMsg::AddFloat`. Not available is the bit pattern `0x7fffffff`.
  ///
  /// - Parameter value: The value, or `nil` if not available.
  public mutating func appendFloat32(_ value: Float?) {
    appendLittleEndian(value?.bitPattern ?? 0x7fff_ffff, byteCount: 4)
  }

  // MARK: - Strings and bytes

  /// Appends a fixed-length string field.
  ///
  /// Ports `tN2kMsg::AddStr`. The string's UTF-8 bytes are copied up to
  /// `count` bytes or the first NUL, and the rest of the field is filled with
  /// `padding`.
  ///
  /// - Parameters:
  ///   - string: The string, or `nil` to write only padding.
  ///   - count: The field width, in bytes.
  ///   - padding: The byte that fills the unused part of the field.
  public mutating func appendFixedString(_ string: String?, count: Int, padding: UInt8 = 0xff) {
    precondition(count >= 0, "Field width must not be negative")
    ensureCapacity(count)
    var written = 0
    for byte in (string ?? "").utf8 {
      guard written < count, byte != 0 else { break }
      data.append(byte)
      written += 1
    }
    data.append(contentsOf: repeatElement(padding, count: count - written))
  }

  /// Appends a fixed-length AIS string field.
  ///
  /// Ports `tN2kMsg::AddAISStr`. Letters are upper-cased, every byte outside
  /// the AIS 6-bit character range `0x20...0x5f` becomes `?`, and the rest of
  /// the field is filled with `@`. A non-ASCII character becomes one `?` for
  /// each of its UTF-8 bytes, as upstream does. The field is truncated to the
  /// remaining capacity.
  ///
  /// - Parameters:
  ///   - string: The string, or `nil` to write only padding.
  ///   - count: The field width, in bytes.
  public mutating func appendAISString(_ string: String?, count: Int) {
    var remaining = count
    for byte in (string ?? "").utf8 {
      guard remaining > 0, byte != 0, data.count < Message.maxDataCount else { break }
      let upper = (0x61...0x7a).contains(byte) ? byte - 0x20 : byte
      data.append((0x20...0x5f).contains(upper) ? upper : UInt8(ascii: "?"))
      remaining -= 1
    }
    let padding = min(remaining, availableCount)
    if padding > 0 {
      data.append(contentsOf: repeatElement(UInt8(ascii: "@"), count: padding))
    }
  }

  /// Appends a variable-length string field.
  ///
  /// Ports `tN2kMsg::AddVarStr`. The field is a length byte (including the two
  /// header bytes), an encoding byte (`1` for ASCII, `0` for UCS-2), then the
  /// characters. A string that is all ASCII is always written as ASCII. Other
  /// strings are written as little-endian UCS-2 when `encoding` is
  /// ``VariableStringEncoding/unicode``, with characters outside the Basic
  /// Multilingual Plane replaced by `?`. Otherwise each non-ASCII character
  /// becomes `?`.
  ///
  /// The string is truncated to `maxLength` and to the remaining capacity
  /// exactly as upstream truncates it, including upstream's behaviour of
  /// leaving the last two bytes of a UCS-2 limit unused. An empty or `nil`
  /// string is written as an empty field.
  ///
  /// - Parameters:
  ///   - string: The string, or `nil` for an empty field.
  ///   - maxLength: The most characters to write, measured in `lengthUnit`.
  ///   - encoding: Whether non-ASCII characters may be written as UCS-2.
  ///   - lengthUnit: The unit that `maxLength` counts.
  public mutating func appendVariableString(
    _ string: String?,
    maxLength: Int = 5000,
    encoding: VariableStringEncoding = .unicode,
    lengthUnit: VariableStringLengthUnit = .bytes
  ) {
    // Upstream works on C strings, so anything after a NUL is ignored.
    let utf8 = Array((string ?? "").utf8.prefix { $0 != 0 })
    var free = max(0, availableCount)
    if free <= 2 || utf8.isEmpty {
      if free >= 2 {
        appendUInt8(2)
        appendUInt8(1)
      } else if free == 1 {
        appendUInt8(1)
      }
      return
    }

    let start = data.count
    var type: UInt8 = 1
    appendUInt8(2)
    appendUInt8(type)
    free -= 2

    let length: Int
    if utf8.contains(where: { $0 >= 0x80 }) {
      switch encoding {
      case .unicode:
        let limit = lengthUnit == .characters ? maxLength * 2 : maxLength
        length = appendUCS2(utf8, capacity: min(free, limit))
        type = 0
      case .asciiOnly:
        length = appendASCIIReplacingNonASCII(utf8, capacity: min(free, maxLength))
      }
    } else {
      length = min(utf8.count, maxLength, free)
      data.append(contentsOf: utf8.prefix(length))
    }
    data[start] = UInt8(truncatingIfNeeded: length + 2)
    data[start + 1] = type
  }

  /// Appends raw bytes, truncated to the remaining capacity.
  ///
  /// Ports `tN2kMsg::AddBuf`.
  ///
  /// - Parameter bytes: The bytes to append.
  public mutating func appendBytes(_ bytes: some Collection<UInt8>) {
    data.append(contentsOf: bytes.prefix(max(0, availableCount)))
  }

  // MARK: - Patching earlier fields

  /// Replaces a byte that was already written.
  ///
  /// Ports `tN2kMsg::SetByte`. Upstream's encoders use it to update a count
  /// field after appending repeated fields.
  ///
  /// - Parameters:
  ///   - value: The new byte.
  ///   - index: The byte's offset in ``data``.
  public mutating func setUInt8(_ value: UInt8, at index: Int) {
    precondition(data.indices.contains(index), "Index \(index) has not been written")
    data[index] = value
  }

  /// Replaces an unsigned 16-bit integer that was already written.
  ///
  /// Ports `tN2kMsg::Set2ByteUInt`.
  ///
  /// - Parameters:
  ///   - value: The new value.
  ///   - index: The offset of the value's first byte in ``data``.
  public mutating func setUInt16(_ value: UInt16, at index: Int) {
    precondition(index >= 0 && index + 1 < data.count, "Index \(index) has not been written")
    data[index] = UInt8(truncatingIfNeeded: value)
    data[index + 1] = UInt8(truncatingIfNeeded: value >> 8)
  }

  /// Discards bytes written after a given position.
  ///
  /// Ports upstream encoders that assign `N2kMsg.DataLen` directly to undo a
  /// partly written entry.
  ///
  /// - Parameter count: The number of bytes to keep.
  public mutating func truncate(to count: Int) {
    precondition(count >= 0 && count <= data.count, "Can't truncate to \(count) bytes")
    data.removeLast(data.count - count)
  }

  // MARK: - Private

  /// Divides by the resolution and rounds half away from zero, like C's
  /// `round()`.
  private static func scale(_ value: Double, _ resolution: Double) -> Double {
    (value / resolution).rounded(.toNearestOrAwayFromZero)
  }

  private func ensureCapacity(_ byteCount: Int) {
    precondition(
      byteCount <= availableCount,
      "Message payload would exceed \(Message.maxDataCount) bytes")
  }

  private mutating func appendLittleEndian(_ value: some FixedWidthInteger, byteCount: Int) {
    ensureCapacity(byteCount)
    var bits = UInt64(truncatingIfNeeded: value)
    for _ in 0..<byteCount {
      data.append(UInt8(truncatingIfNeeded: bits))
      bits >>= 8
    }
  }

  /// Ports upstream's `N2kUTF8ToUCS2`. Returns the number of bytes written.
  private mutating func appendUCS2(_ utf8: [UInt8], capacity: Int) -> Int {
    var length = 0
    var i = 0
    // Upstream stops while two bytes of room remain; keep that for parity.
    while i < utf8.count && length < capacity - 2 {
      let lead = utf8[i]
      let unit: UInt16
      let sequenceLength: Int
      if lead & 0x80 == 0 {
        (unit, sequenceLength) = (UInt16(lead), 1)
      } else if lead & 0xe0 == 0xc0 {
        unit = UInt16(lead & 0x1f) << 6 | UInt16(utf8[i + 1] & 0x3f)
        sequenceLength = 2
      } else if lead & 0xf0 == 0xe0 {
        unit =
          UInt16(lead & 0x0f) << 12 | UInt16(utf8[i + 1] & 0x3f) << 6
          | UInt16(utf8[i + 2] & 0x3f)
        sequenceLength = 3
      } else {
        // Outside the Basic Multilingual Plane: UCS-2 can't represent it.
        (unit, sequenceLength) = (UInt16(UInt8(ascii: "?")), 4)
      }
      data.append(UInt8(truncatingIfNeeded: unit))
      data.append(UInt8(truncatingIfNeeded: unit >> 8))
      i += sequenceLength
      length += 2
    }
    return length
  }

  /// Ports upstream's `N2kUTF8ToASCII`. Returns the number of bytes written.
  private mutating func appendASCIIReplacingNonASCII(_ utf8: [UInt8], capacity: Int) -> Int {
    var length = 0
    var i = 0
    while i < utf8.count && length < capacity {
      let lead = utf8[i]
      if lead & 0x80 == 0 {
        data.append(lead)
        i += 1
      } else {
        data.append(UInt8(ascii: "?"))
        i += lead & 0xe0 == 0xc0 ? 2 : lead & 0xf0 == 0xe0 ? 3 : 4
      }
      length += 1
    }
    return length
  }
}

/// The characters a variable-length string field may hold.
///
/// Ports upstream's `tN2kMsg::tVarStrSupport`.
public enum VariableStringEncoding: Sendable, Hashable {
  /// Replace each non-ASCII character with `?` (`vss_ForceASCII`).
  case asciiOnly
  /// Write strings with non-ASCII characters as UCS-2 (`vss_SupportUnicode`).
  case unicode
}

/// The unit a variable-length string's maximum length is measured in.
///
/// Ports upstream's `tN2kMsg::tVarStrLen`.
public enum VariableStringLengthUnit: Sendable, Hashable {
  /// The maximum length counts bytes (`vsl_UseBytes`).
  case bytes
  /// The maximum length counts characters, so a UCS-2 string may use twice as
  /// many bytes (`vsl_UseCharacters`).
  case characters
}
