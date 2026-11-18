# Porting notes

These notes are for people working on the port. To use the library, start with the guides in the DocC catalog, [`Sources/NMEA2000/NMEA2000.docc`](../Sources/NMEA2000/NMEA2000.docc), and the examples in [`Snippets`](../Snippets).

| File | What it covers |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to build, test and send a change, and the rules a change has to follow |
| [coverage.md](coverage.md) | Upstream's public API, file by file, and what ports each part |
| [upstream-sync.md](upstream-sync.md) | The upstream commit the port matches, and how to bring newer changes across |
| [porting-pgns.md](porting-pgns.md) | The recipe for porting a PGN |
| [field-codec.md](field-codec.md) | `tN2kMsg` helpers and their `MessageWriter` and `MessageReader` equivalents, and the PGN divergences |
| [types.md](types.md) | Upstream's enums and their Swift types, and the enum divergences |
| [node.md](node.md) | `tNMEA2000`: CAN frames, the node, transport protocol, network management, group functions and the device list |
| [gateway.md](gateway.md) | The Actisense and SeaSmart formats |
| [proprietary.md](proprietary.md) | The Maretron and CZone PGNs |
| [linux.md](linux.md) | The pinned build environment and how to update it |
