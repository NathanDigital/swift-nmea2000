# Node and CAN frames: upstream → Swift mapping

Upstream's `tNMEA2000` (`NMEA2000.h/.cpp`) is one class that talks to the CAN driver, splits and reassembles frames, claims an address, answers ISO requests and group functions, and dispatches received messages. This port splits it into layers, each of which can be tested on its own against upstream's node:

1. **CAN frames** (`Sources/NMEA2000/CAN/`, done): pure value types that turn messages into frames and back.
2. **Transport and node** (`Sources/NMEA2000/Node/`, done): a transport protocol for CAN drivers, and an actor that opens it, claims an address, sends messages and delivers received ones as an `AsyncSequence`.
3. **ISO transport protocol**: multi-packet sessions (BAM, RTS/CTS) for messages over 223 bytes or sent to one device.
4. **Network management**: ISO requests, product and configuration information, heartbeat, PGN lists and group functions.

## CAN frames

| Upstream | Swift |
|---|---|
| `CANSendFrame` / `CANGetFrame` arguments (`id`, `len`, `buf`) | `CANFrame` |
| `CanIdToN2k` | `CANIdentifier(frameID:)` |
| `N2ktoCanID` | `CANIdentifier.frameID` (`nil` where upstream returns 0) |
| `IsDefaultSingleFrameMessage`, `IsDefaultFastPacketMessage` | `PGNCatalog.defaultSingleFramePGNs`, `.defaultFastPacketPGNs` |
| `IsMandatoryFastPacketMessage`, `IsSingleFrameSystemMessage`, `IsFastPacketSystemMessage` | `PGNCatalog.mandatoryFastPacketPGNs`, `.singleFrameSystemPGNs`, `.fastPacketSystemPGNs` |
| `IsProprietaryFastPacketMessage`, `IsProprietaryMessage` | `PGNCatalog.isProprietaryFastPacket(_:)`, `.isProprietary(_:)` |
| `SetSingleFrameMessages` / `SetFastPacketMessages` | assign `PGNCatalog.singleFramePGNs` / `.fastPacketPGNs` |
| `ExtendSingleFrameMessages` / `ExtendFastPacketMessages` | insert into those sets |
| `IsFastPacketPGN` | `PGNCatalog.isFastPacket(_:)` |
| `CheckKnownMessage` | `PGNCatalog.classify(_:)` (internal) |
| `DefTransmitMessages` | `MessageFramer.defaultTransmitPGNs` |
| `SendMsg` (single-frame and fast-packet paths) | `MessageFramer.frames(for:)` |
| `GetSequenceCounter`, `GetFastPacketTxPGNCount` | `MessageFramer`'s sequence counters, sized from `init(catalog:transmitPGNs:)` |
| `SetN2kCANBufMsg`, `FindFreeCANMsgIndex`, `tN2kCANMsg` | `MessageAssembler.receive(_:at:)` |
| `SetN2kCANMsgBufSize` (default 5) | `MessageAssembler(bufferCount:)` |
| `SetHandleOnlyKnownMessages` | `MessageAssembler.handlesOnlyKnownMessages` |
| `Max_N2kMsgBuf_Time` (100 ms) | `MessageAssembler.bufferTimeout` |
| `N2kIsTimeBefore`, `N2kHasElapsed` | `isTime(_:before:)`, `hasElapsed(_:since:at:)` (internal) |

Time in the frame layer is a wrapping millisecond counter, as upstream's `millis()` is, so the node can hand it any clock.

### Kept upstream behaviour

- A message of up to eight bytes is sent as a single frame unless its PGN is a fast-packet PGN; anything longer is sent as a fast packet whatever its PGN.
- Sending consults only the fast-packet lists, while receiving checks the single-frame list first, so a PGN in both lists is sent as a fast packet but received as a single frame.
- Sequence counters: a PGN's first fast packet uses sequence 0. Fast-packet PGNs get a dedicated counter in the order they're first sent, with one slot per fast-packet PGN in the default and device transmit lists. Any other PGN shares one counter, which advances before its first use.
- A continuation frame is matched to its fast packet by PGN and source only, not destination. A frame out of sequence discards the fast packet.
- When every reassembly buffer is busy, a new fast packet takes the oldest buffer once it is 100 ms old.

### Divergences

| Upstream | Swift | Why |
|---|---|---|
| `SendMsg` copies six bytes into a fast packet's first frame even when the payload is shorter, sending stale buffer bytes | `MessageFramer` pads with `0xff` | Upstream's bytes are undefined, so there's nothing to match. `0xff` matches its padding of later frames. |
| `SetN2kCANBufMsg` reads the frame counter and length from leftover buffer bytes when a fast-packet frame is too short to hold them | `MessageAssembler` ignores the frame | Upstream's result is undefined. |
| `N2ktoCanID` shifts PGNs wider than 18 bits into the priority bits | `CANIdentifier.frameID` returns `nil` | No valid PGN is that wide. |
| `IsFastPacket` sends a message as a single frame when its priority is `0x80` or more | Not ported | `Message.priority` holds three bits. If a use comes up, it would be an explicit option rather than an out-of-range priority. |

### Testing

`scripts/upstream-vectors Frames` runs upstream's own `tNMEA2000` against a fake CAN driver and a clock the cases control (`Tools/UpstreamVectors/frames.cpp`). It prints each frame the node sends and each message it delivers. `Tests/NMEA2000Tests/CAN/` replays the same cases through the Swift types and compares the results.

## Transport and node

| Upstream | Swift |
|---|---|
| `CANOpen`, `CANSendFrame`, `CANGetFrame` (driver virtuals) | `CANTransport.open()`, `.send(_:)`, and the frame sequence `open()` returns |
| `tNMEA2000` (one device) | `Node` actor, driving the internal `NodeEngine` |
| `Open`, `OpenState`, `OpenScheduler` | `Node.run()`; `NodeEngine.openState` |
| `SetMode` | `Node(mode:address:)` |
| `N2km_ListenOnly` | `Node.Mode.listenOnly` |
| `N2km_SendOnly`, `N2km_ListenAndSend` | `Node.Mode.listenAndSend` |
| `N2km_NodeOnly`, `N2km_ListenAndNode` | `Node.Mode.node` |
| `SendMsg` returning `false` | `Node.send(_:)` throwing `NodeError` |
| `ParseMessages`, `SetMsgHandler`, `AttachMsgHandler` | `Node.run()` and `Node.messages()` |
| `tDeviceInformation`, `SetDeviceInformation`, `GetName` | `DeviceName` |
| `SetN2kPGN60928` / `SetN2kISOAddressClaim` | `ISOAddressClaim` |
| `StartAddressClaim`, `IsAddressClaimStarted`, `HandleISOAddressClaim`, `GetNextAddress`, `UpdateAddressClaimEndSource` | `NodeEngine` (internal) |
| `GetN2kSource`, `ReadResetAddressChanged` | `Node.address` |
| `millis()`, `tN2kScheduler` | the `Clock` passed to `Node(clock:)` |

`NodeEngine` holds all the node's decisions and does no I/O: the actor feeds it the time, the result of opening the transport and the received frames, and sends the frames it returns. The tests drive it exactly as the harness drives upstream's node, so its timing can be compared millisecond for millisecond.

### Kept upstream behaviour

- After the transport opens, the node waits 200 ms, then claims its address. A transport that fails to open is tried again a second later. Frames that arrive before the claim are discarded.
- An address claim lasts 250 ms. During it, the node sends nothing but address claims.
- Against a claim for its address from a higher NAME, the node claims the address again. Against a lower NAME, it moves to the next address, wrapping from 251 to 0, and gives up with address 254 after trying every address once. Against its own NAME during its claim, it adds one to its device instance and claims again.
- A node created with address 254 starts claiming from 14.
- Received system messages, address claims included, are delivered to the application as well as handled.
- Deadlines are reached at their exact millisecond, as on upstream's 32-bit Arduino timer. Upstream's 64-bit builds (ESP32, Linux) reach them a millisecond later.

### Not yet ported

- Several devices on one node (`SetDeviceCount`).
- Commanded address (PGN 65240), which needs the ISO transport protocol.
- Heartbeat, ISO requests, product and configuration information, PGN lists and group functions (layer 4).
- Forwarding to a stream (`SetForwardStream`, debug modes): gateway formats will be separate codecs.
- The send frame buffer (`SetN2kCANSendFrameBufSize`): `CANTransport.send(_:)` suspends while the transport is busy instead.

### Testing

The `Node` cases in `Tools/UpstreamVectors/frames.cpp` poll upstream's node every 10 ms, as a main loop would, and print each event with its time. `Tests/NMEA2000Tests/Node/NodeEngineTests.swift` replays them. `NodeTests.swift` checks the actor's wiring with a manual clock and a fake transport.
