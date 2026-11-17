# Porting a PGN

Each PGN is one struct conforming to `ParameterGroup`, in its own file under `Sources/NMEA2000/PGNs/`. `PGN129025PositionRapidUpdate.swift` is the reference example.

## Steps

1. Find the upstream pair in `src/N2kMessages.cpp`, e.g. `SetN2kPGN129025` and `ParseN2kPGN129025`, and the matching declaration and doc comment in `src/N2kMessages.h`.
2. Create `Sources/NMEA2000/PGNs/PGN<number><Name>.swift`. Name the type by meaning (`PositionRapidUpdate`), not by number.
3. Write the doc comment. Start with a one-line summary, then say which upstream functions it ports: "Ports `SetN2kPGN129025` / `ParseN2kPGN129025`."
4. Set `static let pgn` and `static let defaultPriority`. The priority is the `N2kMsg.Priority=…` line in the `Set` function.
5. Add one stored property per upstream parameter.
   - Use `Double?` for scaled values, where `nil` means not available.
   - Keep upstream's units (SI, except where upstream uses degrees, as it does for latitude and longitude), and state the unit in each property's doc comment.
   - For `tN2k…` enum parameters, use the Swift type listed in [types.md](types.md). Unknown raw values are preserved automatically.
   - Port upstream's default arguments, from both `SetN2kPGN…` and its `SetN2k…` alias in `N2kMessages.h`, as Swift defaults, with defaulted parameters last. Give list properties a default of `[]`.
6. Translate the `Set` body into `encode(into:)` line by line, using the mapping in [field-codec.md](field-codec.md). Write reserved bits and bytes exactly as upstream does.
7. Translate the `Parse` body into `init(decoding:)` the same way. Leave out the PGN check, because `ParameterGroup.init(_:)` does it. Only throw where upstream's `Parse` returns `false` for a reason other than a PGN mismatch.
8. Add cases for the PGN to `Tools/UpstreamVectors/vectors.cpp`, named `PGN<number> <description>`. Include typical values, an all-not-available case, a `defaults` case that calls upstream with only its required arguments, and any edge cases the encoder handles specially. Run `scripts/upstream-vectors PGN<number>` to print the bytes upstream produces.
9. Add `Tests/NMEA2000Tests/PGNs/PGN<number><Name>Tests.swift` with a `vectors` table of values and the bytes from step 8, and these tests (helpers in `TestSupport.swift`):
   - `expectEncodes(_:as:priority:)` for each vector, which checks the bytes and upstream's priority
   - `expectDecodes(_:as:)` for each vector, which decodes upstream's bytes, checks that they re-encode identically, and compares the decoded value with the vector's value field by field (doubles to within rounding). Where encoding loses information (truncated or upper-cased text, masked fields, capped lists), list what the bytes decode to in a `decodedValues` table keyed by vector index, built with `with(vectors[i].0) { … }`
   - `expectTolerantDecoding(_:from:)`, which checks that every prefix of a payload decodes and that another PGN is rejected
   - a test for each upstream quirk the type documents
10. Commit, then run `scripts/mutation-test Sources/NMEA2000/PGNs/PGN<number>*.swift`. For each surviving mutant, add an upstream vector or test that catches it: unknown enum values with high bits set, negative numbers for signed fields, values beyond the signed range for unsigned fields, names past their length limit, and lists that end exactly at the message capacity.

## Upstream patterns and their Swift equivalents

| Upstream | Swift |
|---|---|
| Several `SetN2kPGNxxxx` overloads for one PGN | One type, with convenience initializers if they help |
| `AppendN2kPGNxxxx` adding repeated entries | An array property. `encode(into:)` stops when `writer.availableCount` is too small, as upstream's `Append` does |
| `ParseN2kPGNxxxx(msg, index, item)` for repeated entries | Decode the whole array in `init(decoding:)` |
| `SetN2kXxx` inline aliases | Not ported. The type name already conveys the meaning |
