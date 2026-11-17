# Field codec: upstream → Swift mapping

Upstream's `tN2kMsg` both holds a message and reads and writes its fields. This port splits those jobs across three types:

- `Message` holds the header and payload.
- `MessageWriter` appends fields, used by PGN encoders. It ports `SetN2kPGN…` bodies.
- `MessageReader` reads fields in order, used by PGN decoders. It ports `ParseN2kPGN…` bodies.

Every upstream helper has exactly one Swift equivalent with the same width, resolution, rounding and "not available" (NA) semantics, so porting a Set/Parse body means translating it line by line in the same field order.

## Message

| Upstream `tN2kMsg` | Swift `Message` |
|---|---|
| `Priority`, `PGN`, `Source`, `Destination` | `priority`, `pgn`, `source`, `destination` |
| `Data`, `DataLen` | `data` (`[UInt8]`) |
| `MsgTime` | `timestamp` (milliseconds) |
| `IsTPMessage()` / `SetIsTPMessage()` | `isTransportProtocol` |
| `MaxDataLen` (223) | `Message.maxDataCount` |
| `IsValid()` | `isValid` |
| Constructor defaults (source 15, priority 6, broadcast) | `init(pgn:priority:source:destination:…)` with the same defaults |

## Writing: `tN2kMsg::Add…` → `MessageWriter`

Scaled values take a `Double?`. `nil` replaces upstream's `N2kDoubleNA` sentinel and writes the field's NA pattern. When an upstream call passes a custom `UndefVal`, convert that value to `nil` at the call site.

| Upstream | Swift | NA | Out of range |
|---|---|---|---|
| `AddByte(v)` | `appendUInt8(_:)` | | |
| `Add2ByteInt(v)` | `appendInt16(_:)` | | |
| `Add2ByteUInt(v)` | `appendUInt16(_:)` | | |
| `Add3ByteInt(v)` | `appendInt24(_:)` | | |
| `Add4ByteUInt(v)` | `appendUInt32(_:)` | | |
| `AddUInt64(v)` | `appendUInt64(_:)` | | |
| `Add1ByteDouble(v, p)` | `appendInt8(_:resolution:)` | `0x7f` | `0x7e` |
| `Add1ByteUDouble(v, p)` | `appendUInt8(_:resolution:)` | `0xff` | `0xfe` |
| `Add2ByteDouble(v, p)` | `appendInt16(_:resolution:)` | `0x7fff` | `0x7ffe` |
| `Add2ByteUDouble(v, p)` | `appendUInt16(_:resolution:)` | `0xffff` | `0xfffe` |
| `Add3ByteDouble(v, p)` | `appendInt24(_:resolution:)` | `0x7fffff` | `0x7ffffe` |
| `Add3ByteUDouble(v, p)` | `appendUInt24(_:resolution:)` | `0xffffff` | `0xfffffe` |
| `Add4ByteDouble(v, p)` | `appendInt32(_:resolution:)` | `0x7fffffff` | `0x7ffffffe` |
| `Add4ByteUDouble(v, p)` | `appendUInt32(_:resolution:)` | `0xffffffff` | `0xfffffffe` |
| `Add8ByteDouble(v, p)` | `appendInt64(_:resolution:)` | `0x7fffffffffffffff` | see below |
| `AddFloat(v)` | `appendFloat32(_:)` | `0x7fffffff` | |
| `AddStr(s, len, fill)` | `appendFixedString(_:count:padding:)` | | |
| `AddAISStr(s, len)` | `appendAISString(_:count:)` | | |
| `AddVarStr(s, maxLen, support, lenUnit)` | `appendVariableString(_:maxLength:encoding:lengthUnit:)` | | |
| `AddBuf(buf, len)` | `appendBytes(_:)` | | |
| `SetByte(v, idx)` | `setUInt8(_:at:)` | | |
| `Set2ByteUInt(v, idx)` | `setUInt16(_:at:)` | | |
| `GetAvailableDataLength()` | `availableCount` | | |
| `DataLen` (as a position) | `count` | | |

### Optional raw integers

Upstream passes raw integers that may be missing (sequence IDs, dates, counts, waypoint numbers) with all ones (`N2kUInt8NA`, `N2kUInt16NA`, `N2kUInt32NA`) or `N2kInt16NA` meaning "not available". In Swift these are `Optional`:

| Upstream | Swift writer | Swift reader |
|---|---|---|
| `AddByte(v)` / `GetByte(i)` with `N2kUInt8NA` | `appendUInt8(_: UInt8?)` | `readOptionalUInt8()` |
| `Add2ByteInt(v)` / `Get2ByteInt(i)` with `N2kInt16NA` | `appendInt16(_: Int16?)` | `readOptionalInt16()` |
| `Add2ByteUInt(v)` / `Get2ByteUInt(i)` with `N2kUInt16NA` | `appendUInt16(_: UInt16?)` | `readOptionalUInt16()` |
| `Add4ByteUInt(v)` / `Get4ByteUInt(i)` with `N2kUInt32NA` | `appendUInt32(_: UInt32?)` | `readOptionalUInt32()` |
| `N2kMsg.DataLen=n` (undo a partial entry) | `truncate(to:)` | |

Rounding matches C's `round()` (half away from zero), except for `appendInt64`, which truncates toward zero as upstream does. Unsigned fields write their out-of-range pattern for negative values, and every scaled field writes its out-of-range pattern for NaN.

## Reading: `tN2kMsg::Get…` → `MessageReader`

Upstream's decoders keep an `int Index` and pass it by reference. `MessageReader` keeps it internally (`index`). Upstream code that adds to `Index` directly becomes `skip(_:)`.

| Upstream | Swift | Past the end |
|---|---|---|
| `GetByte(i)` | `readUInt8()` | `0xff` |
| `Get2ByteInt(i)` | `readInt16()` | `0x7fff` |
| `Get2ByteUInt(i)` | `readUInt16()` | `0xffff` |
| `Get3ByteUInt(i)` | `readUInt24()` | `0xffffffff` |
| `Get4ByteUInt(i)` | `readUInt32()` | `0xffffffff` |
| `GetUInt64(i)` | `readUInt64()` | all ones |
| `Get1ByteDouble(p, i)` | `readInt8(resolution:)` | `nil` |
| `Get1ByteUDouble(p, i)` | `readUInt8(resolution:)` | `nil` |
| `Get2ByteDouble(p, i)` | `readInt16(resolution:)` | `nil` |
| `Get2ByteUDouble(p, i)` | `readUInt16(resolution:)` | `nil` |
| `Get3ByteDouble(p, i)` | `readInt24(resolution:)` | `nil` |
| `Get3ByteUDouble(p, i)` | `readUInt24(resolution:)` | `nil` |
| `Get4ByteDouble(p, i)` | `readInt32(resolution:)` | `nil` |
| `Get4ByteUDouble(p, i)` | `readUInt32(resolution:)` | `nil` |
| `Get8ByteDouble(p, i)` | `readInt64(resolution:)` | `nil` |
| `GetFloat(i)` | `readFloat32()` | `nil` |
| `GetStr(buf, len, i)` | `readFixedString(count:terminator: 0x40)` | `nil` |
| `GetStr(size, buf, len, nul, i)` | `readFixedString(count:terminator:)` | `nil` |
| `GetVarStr(size, buf, nul, i)` | `readVariableString(terminator:)` | `nil` |
| `GetBuf(buf, len, i)` | `readBytes(count:)` | `nil` |
| `GetRemainingDataLength(i)` | `remainingCount` | |

Scaled reads return `nil` for the field's NA pattern. Upstream returns its `def` argument instead (usually `N2kDoubleNA`). When an upstream call passes a custom `def`, use `?? def` at the call site. As upstream does, the out-of-range pattern decodes as an ordinary value.

A fixed-width read that runs past the end leaves `index` unchanged, as upstream does. Older devices send shorter messages, and their missing trailing fields decode as not available.

## Strings

- Swift strings go onto the wire as their UTF-8 bytes, and anything after an embedded NUL is ignored, as it is for upstream's C strings.
- Fixed and ASCII variable-length strings are decoded as UTF-8, with invalid bytes replaced by U+FFFD.
- `appendVariableString` reproduces upstream's truncation exactly, including the quirk that UCS-2 conversion leaves the last two bytes of its limit unused.
- `appendAISString` turns each UTF-8 byte of a non-ASCII character into `?`, as upstream's byte-wise `toupper` loop does.

## Deliberate divergences from upstream

All of these are cases where upstream's behaviour is a bug or undefined. None of them changes what upstream itself writes for a valid input.

| Upstream | Swift | Why |
|---|---|---|
| `Get3ByteDouble` doesn't sign-extend, so a negative 24-bit value decodes as a large positive one | `readInt24(resolution:)` sign-extends | The field is signed on the wire. Affects PGN 127751 (DC current). |
| `GetBuf` doesn't advance `Index` when it copies into a buffer | `readBytes(count:)` always advances | Later fields would otherwise be read from the wrong offset. |
| `Add8ByteDouble` with a value that doesn't fit in `int64_t` is undefined behaviour | `appendInt64` writes `0x7ffffffffffffffe` | By analogy with the narrower fields' out-of-range pattern. |
| A value equal to the `N2kDoubleNA` sentinel (`-1e9`) is written as NA | Only `nil` is written as NA | Optionals replace the sentinel. |
| Fixed-width `Add…` past `MaxDataLen` overflows the buffer | Traps (`precondition`) | It's a programming error in an encoder. |

## Not ported

- `tN2kMsg::Print`, `PrintBuf`: debug output. `Message` will get a `CustomStringConvertible` description instead.
- `tN2kMsg::SendInActisenseFormat`: will be part of the Actisense codec.
- `tN2kMsg::SetPGN`, `Init`, `Clear`, `ForceSource`, `CheckDestination`: mutable-buffer lifecycle. These become plain property assignment, or move to the node.
- The free `SetBuf…` / `GetBuf…` functions: these are internal to `tN2kMsg`. `SetBufDouble` / `GetBufDouble` (8-byte IEEE double) aren't used by any upstream message, and will be added if a PGN needs them.
