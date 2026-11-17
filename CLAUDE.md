# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A pure-Swift port of [ttlappalainen/NMEA2000](https://github.com/ttlappalainen/NMEA2000), the C++ NMEA 2000 library for Arduino. It is a port, not a transliteration: send exactly the bytes upstream sends, decode what the wire format means, and write the API in idiomatic Swift (see "Fidelity to upstream" below). The repository will be public on GitHub, so code, commits, docs and the README all need to look professional.

**Names:** the repo is `NathanDigital/swift-nmea2000`. The package name is `swift-nmea2000`, and the library product/module is `NMEA2000` (`import NMEA2000`).

**Status:** the message container and field codec (`Sources/NMEA2000/Message/`: `Message`, `MessageWriter`, `MessageReader`) are ported, with the helper mapping in `docs/field-codec.md`. PGN types conform to `ParameterGroup` (`Sources/NMEA2000/Message/ParameterGroup.swift`) and live in `Sources/NMEA2000/PGNs/`. Ported so far: 129025 (the template) the navigation batch (126992, 127250–127258, 128259–128275, 129026–129033, 129283–129285, 129539, 129540, 130074, 130577), steering, windlass and man overboard (127233, 127237, 127245, 128000, 128776–128778), and engine and electrical (127488, 127489, 127493, 127497, 127501, 127502, 127505–127508, 127510, 127513, 127750, 127751); `docs/porting-pgns.md` has the recipe. The upstream enums and data dictionary types are ported in `Sources/NMEA2000/Types/` (mapping in `docs/types.md`). The rest of the layout and mapping below is the intended design. Update this file whenever the real structure differs from it.

## Licensing and attribution

- This project is MIT-licensed, © NathanDigital, matching upstream's MIT license (© 2015-2026 Timo Lappalainen, Kave Oy). `LICENSE` carries both notices, and MIT requires the upstream notice to stay in "all copies or substantial portions". Never remove it.
- Always present the project as a port of Timo Lappalainen's work, in the README, docs and DocC. Never imply the protocol work originated here. The README's disclaimer (not affiliated with NMEA; "NMEA 2000" is NMEA's trademark; not certified) must stay.
- Never copy text from the NMEA 2000 standard into the repository. PGN field layouts come from the upstream source.

## Commands

**Every build, test, lint and format run uses the Swift toolchain in the Docker container**, via `scripts/linux-swift`. The container is Ubuntu 26.04 LTS with the swift.org toolchain, pinned in `docker/Dockerfile` (see `docs/linux.md`). Never run the host's `swift` / `swift build` / `swift test`, or Xcode/xcodebuild builds (including the Xcode MCP's build and test tools). The host has Xcode's toolchain, which is not the target and isn't the same build. The Xcode MCP is still fine for documentation search. Don't use Apple-only APIs.

```sh
scripts/linux-swift build
scripts/linux-swift test
scripts/linux-swift test --filter <SuiteOrTestName>     # run a single suite or test
scripts/linux-swift format lint -s -r Sources Tests     # strict: warnings fail, as in CI
scripts/linux-swift format -i -r Sources Tests          # format in place (no backup; commit first)
scripts/upstream-vectors [filter]                       # bytes upstream's encoders produce (see Testing)
scripts/mutation-test [files]                           # check the tests catch injected bugs (see Testing)
```

`swift-format` ships with the toolchain. Formatting rules live in `.swift-format` at the repo root. Generate a starting config with `scripts/linux-swift format dump-configuration > .swift-format`.

## Upstream → Swift mapping

When porting a feature, read the corresponding upstream file in `src/` (and its test in `test/`) first. To inspect upstream without cloning it, run `gh api repos/ttlappalainen/NMEA2000/contents/src/<file> --jq .content | base64 -d`.

| Upstream | Role | Swift direction |
|---|---|---|
| `N2kMsg.h/.cpp` (`tN2kMsg`) | Message container plus byte-level get/set helpers | A value-type message (`struct`) with a separate reader/writer for fields, using explicit little-endian encoding |
| `N2kMessages.h/.cpp` (`SetN2kPGNxxxx` / `ParseN2kPGNxxxx`) | Encoders and decoders for every supported PGN | One idiomatic struct per PGN, wire-identical to upstream. See "PGN definitions" below |
| `N2kTypes.h`, `N2kMessagesEnumToStr.h` | Enums and their string tables | Swift enums with raw values and `CustomStringConvertible` |
| `NMEA2000.h/.cpp` (`tNMEA2000`) | Node: address claim, fast-packet and ISO TP reassembly, ISO requests, product and config info, handlers | An actor that owns node state, with received messages delivered as an `AsyncSequence` rather than callback function pointers |
| `NMEA2000_CAN.h`, `NMEA2000_CompilerDefns.h` | Compile-time selection of the CAN driver | A transport protocol (send/receive CAN frames) that is injected at runtime. Drivers ship as separate targets or packages |
| `N2kTimer`, `millis()` | Timing | Inject a `Clock` so that tests can control time |
| `RingBuffer` | Fixed buffers for MCUs | Standard collections unless profiling shows they're a problem |
| `N2kGroupFunction*`, `N2kDeviceList` | PGN 126208 group functions, device discovery | Separate types layered on the node |
| `ActisenseReader`, `Seasmart`, `N2kStream` | Gateway serial formats and output streams | Pure codecs (bytes ↔ messages) with no I/O |
| `N2kMaretron`, `N2kCZone` | Proprietary PGNs | Separate files or targets so the core stays standard-only |

## PGN definitions: bus compatibility and easy porting from upstream

### Fidelity to upstream

Upstream is the single master source for **what** is ported: which PGNs, fields and enum values exist. Don't add PGNs, fields or named enum values that upstream doesn't have, even if canboat or another source defines them; unnamed values still round-trip as raw values. Other sources (canboat, manufacturer manuals) are only used to check a value upstream already defines when it looks wrong (rule 2).

Upstream's bytes are proven on real buses, so matching them is how we know we interoperate. Its decoders and enum names are less reliable. Apply these rules in order:

1. **Encoding is byte-identical to upstream by default**, including odd but harmless choices (e.g. an empty waypoint name sent as a single NUL, UCS-2 strings leaving two bytes unused). Tests check this against `scripts/upstream-vectors`.
2. **Exception: upstream sends the wrong meaning.** If upstream puts a value on the bus that means something other than what its API promises (e.g. `N2kDCVS_Low` defined as 3, which is "not available"), send the correct value instead. Confirm the correct value from canboat (`canboat/canboat`, `analyzer/*-generated-data.h`) or upstream's own sibling definitions, never the NMEA standard text.
3. **Decoding follows what the wire format means, not upstream's accidents.** Keep deliberate filtering (masking reserved bits, `SetEvents`), but fix decoders that lose information or produce values that can't round-trip (e.g. reading one bit of a two-bit field). Decoder fixes never change the bytes we send.
4. **The Swift API is ours to design**: idiomatic names, `Optional` for not available, upstream's default arguments ported as Swift defaults, parameters in a sensible order. Wire order lives in `encode(to:)`.

Every divergence under rules 2 and 3 gets a test, a note in the type's doc comment, and a row in the divergence table of `docs/field-codec.md` (PGNs and codec) or `docs/types.md` (enums).

Goal: every PGN's **wire format** (field order, widths, resolutions, signedness, reserved bits, "not available" encodings) is byte-identical to upstream (apart from rule 2 above), and a new PGN or PGN bugfix added upstream can be ported quickly and mechanically. The Swift API and internals do **not** mirror upstream. They follow Swift best practice.

- **One idiomatic type per PGN.** Each PGN is a `Sendable` struct conforming to a shared message protocol (PGN number, default priority, decode from and encode to a message). Name types by meaning (`PositionRapidUpdate`), not `SetN2kPGN129025`. Each file is named after its PGN, e.g. `PGN129025PositionRapidUpdate.swift`, so it can be found by number.
- **Traceability.** Each PGN type's doc comment names the upstream functions it ports (e.g. "Ports `SetN2kPGN129025` / `ParseN2kPGN129025`"), so grepping an upstream diff's function name leads straight to the Swift file.
- **Field codec primitives map 1:1 onto `tN2kMsg`'s helpers** (`Add2ByteUDouble`, `Get4ByteDouble`, `AddByte`, …). Each upstream helper has exactly one Swift writer/reader equivalent with the same width, resolution and NA semantics. That makes porting a Set/Parse body a line-by-line translation in the same field order. Keep the mapping table in `docs/`.
- **"Not available"** is `Optional` in the Swift API. The codec layer converts `nil` ↔ upstream's NA encodings (`N2kDoubleNA` etc.), keeping upstream's distinction between "not available" and "out of range" where it exists.
- **Enums** port upstream's `tN2k…` enums with the same raw values, but decoding must not fail on unknown values. New devices send values we don't know yet, so preserve the raw value (e.g. an `.unknown(UInt8)` case or a `RawRepresentable` struct) and re-encode it unchanged.
- **Tolerate newer devices.** Decoders ignore trailing bytes beyond the fields they know, as upstream does. Reserved bits are written exactly as upstream writes them.
- Proprietary PGNs (`N2kMaretron`, `N2kCZone`) follow the same rules in their own targets or folders.
- Record the upstream commit last synced in `docs/upstream-sync.md`. To find new or fixed PGNs, diff from that commit and look at `src/N2kMessages.*` and `src/N2kTypes.h`.

## Conventions

- **Swift API Design Guidelines** (https://www.swift.org/documentation/api-design-guidelines/): prioritise clarity at the point of use. Drop C++ prefixes (`t`, `N2k` Hungarian-style names, `Set`/`Parse` verbs) wherever the module namespace already gives that context. Factory methods start with `make`, Booleans read as assertions (`isFastPacket`), and acronyms are cased uniformly (`pgn`, `PGN`).
- **Swift 6 language mode with strict concurrency.** Public value types are `Sendable`.
- **Units:** upstream uses SI units on the wire API (radians, kelvin, m/s, pascals). Keep them as SI and document the unit on every property.
- **Pure Swift:** avoid platform-only frameworks in the core target so it builds on Linux. Keep any Foundation use deliberate and minimal.
- **Errors:** throw typed errors (e.g. a payload too short for its required fields) rather than returning `false`.
- **Documentation:** every public declaration gets a `///` comment that starts with a single-sentence-fragment summary (per the API Design Guidelines). API reference uses DocC. Prose docs (guides, porting notes) go in `/docs`.

## Testing

- Use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest.
- **Wire-format parity with upstream is the main correctness bar.** For each ported PGN, add tests that encode known values and compare the bytes to what upstream produces, plus round-trip decode tests. Port the vectors from upstream `test/*.cpp` where they exist.
- Use parameterized `@Test(arguments:)` for tables of PGN vectors rather than one test per case.
- **Expected bytes come from upstream, not from hand calculation.** Add a case to `Tools/UpstreamVectors/vectors.cpp` that calls upstream's `SetN2kPGN…` (or a `tN2kMsg::Add…` helper), run `scripts/upstream-vectors <filter>`, and paste the printed bytes into the Swift test. The script fetches upstream at the commit in `docs/upstream-sync.md` into `.upstream/` (git-ignored) and compiles the harness with `clang++` in the same pinned container, with the repo mounted read-only. Don't run `docker` directly for this; use the script.
- **Mutation-test new code.** `scripts/mutation-test <files>` makes one small change at a time (resolution, mask, shift, flag bit, signedness, reserved or NA value, capacity check, dropped field), runs the suite, and restores the file. A surviving mutant means a test input or assertion is missing. Fix it with a new upstream vector, typically a value with high bits set, a negative number, or a list that lands exactly on a capacity limit. If a mutant can't change behaviour, say so in the commit. It edits files in place, so commit first; it refuses to run on uncommitted target files.
