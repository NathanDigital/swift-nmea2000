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
6. Translate the `Set` body into `encode(to:)` line by line, using the mapping in [field-codec.md](field-codec.md). Write reserved bits and bytes exactly as upstream does.
7. Translate the `Parse` body into `init(from:)` the same way. Leave out the PGN check, because `ParameterGroup.init(_:)` does it. Only throw where upstream's `Parse` returns `false` for a reason other than a PGN mismatch.
8. Add cases for the PGN to `Tools/UpstreamVectors/vectors.cpp`, named `PGN<number> <description>`. Include typical values, an all-not-available case, and any edge cases the encoder handles specially. Run `scripts/upstream-vectors PGN<number>` to print the bytes upstream produces.
9. Add `Tests/NMEA2000Tests/PGNs/PGN<number><Name>Tests.swift` with these tests:
   - a parameterized table of values and the bytes printed in step 8, used for both encoding and decoding, and including the all-not-available case
   - any vectors from upstream `test/N2kMessagesTest.cpp` for this PGN
   - a short payload decoding its missing fields as `nil`
   - a message with a different PGN being rejected

## Upstream patterns and their Swift equivalents

| Upstream | Swift |
|---|---|
| Several `SetN2kPGNxxxx` overloads for one PGN | One type, with convenience initializers if they help |
| `AppendN2kPGNxxxx` adding repeated entries | An array property. `encode(to:)` stops when `writer.availableCount` is too small, as upstream's `Append` does |
| `ParseN2kPGNxxxx(msg, index, item)` for repeated entries | Decode the whole array in `init(from:)` |
| `SetN2kXxx` inline aliases | Not ported. The type name already conveys the meaning |
