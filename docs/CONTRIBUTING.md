# Contributing

This project is a Swift port of [Timo Lappalainen's NMEA2000 library](https://github.com/ttlappalainen/NMEA2000). A change is welcome when it brings the port closer to upstream, fixes a bug, or improves the Swift API or the documentation.

## Build and test

The only tool to install is Docker. `scripts/linux-swift` runs `swift` in the pinned build image ([linux.md](linux.md)); don't use a toolchain installed on your own machine, because it isn't the one CI uses.

```sh
scripts/linux-swift build
scripts/linux-swift test
scripts/linux-swift test --filter <SuiteOrTestName>
scripts/linux-swift format lint -s -r Sources Tests Snippets Package.swift
scripts/check-layering
scripts/linux-swift package generate-documentation --target NMEA2000 --warnings-as-errors
```

CI runs all of these, and a change has to pass them.

## What a change has to follow

- **Upstream decides what is ported.** Don't add PGNs, fields or named enum values that upstream doesn't have. To port something new from upstream, follow [porting-pgns.md](porting-pgns.md) and [upstream-sync.md](upstream-sync.md).
- **The bytes match upstream.** Encoders send exactly what upstream sends. The few deliberate exceptions are listed in the divergence tables of [field-codec.md](field-codec.md) and [types.md](types.md); a new one needs a test, a note in the type's doc comment and a row in the table.
- **Expected bytes come from upstream's code, not from hand calculation.** Add a case to `Tools/UpstreamVectors/vectors.cpp` (or `frames.cpp` for node behaviour), run `scripts/upstream-vectors <filter>`, and use the bytes it prints in the test.
- **Nothing comes from the NMEA 2000 standard's text.** Field layouts come from upstream's source.
- **The API follows the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).** Keep the established NMEA 2000 names for fields and PGNs.
- **The code builds on Linux in Swift 6 language mode**, without Apple-only frameworks.
- **The folders in `Sources/NMEA2000` depend only downwards:** `Support` and `Types`, then `Message`, `PGNs`, `CAN`, and `Gateway`, `Proprietary` and `Node` on top. `scripts/check-layering` checks it.

## Tests

Tests use Swift Testing. Each PGN has a table of values and the bytes upstream produces for them, and checks encoding, decoding and tolerance of short and long payloads; [porting-pgns.md](porting-pgns.md) lists the helpers. After committing new code, run `scripts/mutation-test <files>`, which makes one small change at a time and checks that a test fails, and add a test for each change that survives.

## Documentation

- Every public declaration has a `///` comment that starts with a one-sentence summary, and states the unit of every value.
- A PGN type's comment names the upstream functions it ports.
- Guides for people using the library are articles in the DocC catalog, `Sources/NMEA2000/NMEA2000.docc`. Add a new public type to a topic group there.
- Example code goes in `Snippets/`, where it is compiled with the package, and guides embed it with `@Snippet`.
- Notes for people working on the port go in this folder, with a row in [README.md](README.md).

## Licence and attribution

The project is MIT-licensed, as upstream is. `LICENSE` carries both copyright notices, and the upstream notice must stay. By contributing, you agree that your change is released under the same licence.
