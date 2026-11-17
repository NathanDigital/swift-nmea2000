# Node and CAN frames: upstream → Swift mapping

Upstream's `tNMEA2000` (`NMEA2000.h/.cpp`) is one class that talks to the CAN driver, splits and reassembles frames, claims an address, answers ISO requests and group functions, and dispatches received messages. This port splits it into layers, each of which can be tested on its own against upstream's node:

1. **CAN frames** (`Sources/NMEA2000/CAN/`, done): pure value types that turn messages into frames and back.
2. **Transport and node** (`Sources/NMEA2000/Node/`, done): a transport protocol for CAN drivers, and an actor that opens it, claims an address, sends messages and delivers received ones as an `AsyncSequence`.
3. **ISO transport protocol** (done): multi-packet sessions, broadcast (BAM) or to one device (RTS/CTS), received in `MessageAssembler` and sent by `NodeEngine`.
4. **Network management** (done): ISO requests, product and configuration information, heartbeat, PGN lists, commanded address and group functions.

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
| `IsFastPacket` sends a message as a single frame when its priority is `0x80` or more | `Message.forcesSingleFrame` | `Message.priority` holds three bits, so the option is explicit rather than an out-of-range priority. |

### Testing

`scripts/upstream-vectors Frames` runs upstream's own `tNMEA2000` against a fake CAN driver and a clock the cases control (`Tools/UpstreamVectors/frames.cpp`). It prints each frame the node sends and each message it delivers. `Tests/NMEA2000Tests/CAN/` replays the same cases through the Swift types and compares the results.

## Transport and node

| Upstream | Swift |
|---|---|
| `CANOpen`, `CANSendFrame`, `CANGetFrame` (driver virtuals) | `CANTransport.open()`, `.send(_:)`, and the frame sequence `open()` returns |
| `tNMEA2000` | `Node` actor, driving the internal `NodeEngine` |
| `SetDeviceCount`, `tInternalDevice`, the `DeviceIndex` / `iDev` arguments | `Node(devices:)`, `Node.Device`, `Node.devices`, `send(_:from:)` |
| `SetOnOpen`, `ReadResetAddressChanged`, `ReadResetDeviceInformationChanged`, `ReadResetInstallationDescriptionChanged` | `Node.events()` |
| `SetForwardOwnMessages` and the forward stream | `Node.messages(includingSent:)` |
| `SendIsoAddressClaim`, `SendProductInformation`, `SendConfigurationInformation`, `SendTxPGNList`, `SendRxPGNList`, `SendHeartbeat`, `Restart` | `Node.sendAddressClaim`, `sendProductInformation`, `sendConfigurationInformation`, `sendPGNList`, `sendHeartbeat`, `restartAddressClaim` |
| `SetHeartbeatIntervalAndOffset`, `SetDeviceInformationInstances`, `SetProductInformation`, `SetConfigurationInformation` at run time | `Node.setHeartbeatInterval`, `setInstances`, `setProductInformation`, `setConfigurationInformation` |
| `SetN2kCANMsgBufSize` | `Node(bufferCount:)` |
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

### Sending frames

Upstream hands each frame to its CAN driver, and keeps the ones the driver can't take yet in a send frame buffer of 40 frames (`SetN2kCANSendFrameBufSize`). When that buffer is full the frame is lost and `SendMsg` fails, so product and configuration information go pending and are sent again later, and a transport protocol send ends.

`Node` queues frames for `CANTransport.send(_:)`, which suspends while the transport is busy. Up to 40 frames can wait. Beyond that the frames the node sends on its own (claims, heartbeats, answers, transport protocol packets) are dropped, and messages sent with `send(_:from:)` wait for the transport. A dropped frame and a frame the transport fails to send are handled as upstream handles a failed send (`NodeEngine.transmissionFailed`): product and configuration information are tried again 187 ms plus 8 or 10 ms per unit of the address later, a transport protocol send ends when its request to send or BAM fails, or when an addressed data packet fails, and a broadcast send carries on, as upstream sends the next packet regardless. An application's own message that fails isn't retried: `send(_:from:)` throws.

When the transport closes, the node drops every message it was reassembling, since the frames after reconnecting can't continue them. Upstream has no reconnect to compare with. The heartbeat sequence counter carries on across a reconnect and when the heartbeat is turned off and on, as upstream's does.

### Own messages

`messages(includingSent: true)` delivers each message the node hands to the transport, including those whose frames later fail to send, as upstream forwards its own messages whatever the driver does with them. Upstream also forwards a message that `SendMsg` refuses after its first checks, such as a transport protocol message while another is being sent; the port doesn't, because `send(_:from:)` throws for it and nothing went on the bus.

### Not ported

- Forwarding to a stream (`SetForwardStream`, debug modes): see `docs/coverage.md`.

### Testing

The `Node` cases in `Tools/UpstreamVectors/frames.cpp` poll upstream's node every 10 ms, as a main loop would, and print each event with its time. `Tests/NMEA2000Tests/Node/NodeEngineTests.swift` replays them. `NodeTests.swift` checks the actor's wiring with a manual clock and a fake transport.

## ISO transport protocol

| Upstream | Swift |
|---|---|
| `TP_CM`, `TP_DT`, `TP_CM_*`, `TP_MAX_FRAMES`, `TPCtsPackets` | `TransportProtocol` (internal) |
| `SendTPCM_BAM`, `SendTPCM_RTS`, `SendTPCM_CTS`, `SendTPCM_EndAck`, `SendTPCM_Abort`, `SendTPDT` | `TransportProtocol.start`, `.clearToSend`, `.endOfMessage`, `.abort`, `.dataPacket` |
| `TestHandleTPMessage` (receiving) | `MessageAssembler.receive(_:at:)`, which shares its buffers between fast packets and sessions |
| `TestHandleTPMessage` (CTS, ACK, abort for our session), `StartSendTPMessage`, `SendPendingTPMessage`, `EndSendTPMessage` | `NodeEngine`'s transfer |
| `tN2kMsg::SetIsTPMessage` | `Message.isTransportProtocol` |

### Kept upstream behaviour

- A message marked for transport protocol is sent that way only if it doesn't fit a single frame: more than eight bytes, or a fast-packet PGN. A PDU2 PGN is always broadcast.
- Sending: a BAM is followed by one data packet every 50 ms. A request to send must get its first clear to send within 50 ms, and each later one within 100 ms of the last, or the node gives up. A clear to send for zero packets makes the sender wait. One out of sequence, or for another PGN, ends the session, as do an acknowledgement or abort. The node sends one message at a time, and only in `.node` mode. Like `SendMsg`, `Node.send(_:)` returns once the session is announced, without reporting whether the receiver took the message.
- Receiving: a session takes one of the five reassembly buffers, matched by PGN, source, destination and being a session. Each data packet restarts the buffer's 100 ms timeout. Sessions between other devices are reassembled too.
- A request to send to the node gets a clear to send for as many packets as the message has, at most five, read from the request's packet count rather than its maximum-packets byte. A request for 223 bytes or more, or one that finds every buffer busy, is aborted as busy. A packet out of sequence aborts the session with reason 3. Replies are only sent in `.node` mode and outside an address claim.
- A message received by transport protocol has priority 7, and its timestamp is the time of its last data packet. The protocol's own frames are never delivered.

### Divergences

| Upstream | Swift | Why |
|---|---|---|
| `TestHandleTPMessage` reads connection management fields from leftover buffer bytes when the frame is shorter than eight bytes | `MessageAssembler` ignores the frame | Upstream's result is undefined. |

## Network management

| Upstream | Swift |
|---|---|
| `SetN2kPGN59392` / `SetN2kPGNISOAcknowledgement` | `ISOAcknowledgement` |
| `SetN2kPGN59904`, `ParseN2kPGN59904` | `ISORequest` |
| `SetN2kPGN126464`, `tN2kPGNList` | `PGNList`, `PGNList.Kind` |
| `SetN2kPGN126993` / `SetHeartbeat` | `Heartbeat` |
| `SetN2kPGN126996`, `ParseN2kPGN126996`, `tProductInformation`, `DefProductInformation` | `ProductInformation`, `.default` |
| `SetN2kPGN126998`, `ParseN2kPGN126998`, `DefManufacturerInformation` | `ConfigurationInformation`, `.default` |
| `SetProductInformation`, `SetConfigurationInformation` | `Node(productInformation:configurationInformation:)` |
| `ExtendTransmitMessages`, `ExtendReceiveMessages` | `Node(transmitPGNs:receivePGNs:)` |
| `SetHeartbeatIntervalAndOffset` | `Node(heartbeatInterval:)` |
| `HandleISORequest`, `RespondISORequest`, `IgnoreBroadcastISORequest` | `NodeEngine` (internal) |
| `SetISORqstHandler` | `Node.setISORequestHandler(_:)`, which returns the replies instead of sending them |
| `SendHeartbeat` | `NodeEngine` (internal) |
| `HandleCommandedAddress` | `NodeEngine` (internal); PGN 65240 has no public type, as upstream has no encoder or parser for it |

### Kept upstream behaviour

- The node answers ISO requests addressed to it or broadcast, only in `.node` mode and not while claiming its address. It answers 60928 with an address claim; 126464 with its transmit list then its receive list, sent to the requester, each at most 74 PGNs; and 126996 and 126998 by broadcasting its product or configuration information. With no configuration information, it broadcasts a negative acknowledgement for 126998.
- Other requests go to the application's handler, except broadcast requests for the ten PGNs upstream ignores (127500, 130060, 130061, 130330 and 130561–130566). If the handler doesn't answer, an addressed request gets a negative acknowledgement.
- A request shorter than three bytes asks for PGN 0, because upstream ignores the parse failure.
- The first heartbeat is due 10 s after the node opens and later ones every interval after that. Upstream's 64-bit timer sends each once its time has passed, at the first poll after it. Heartbeats wait for an address claim to end, are only sent in `.node` mode, and carry a sequence number that wraps from 252 to 0.
- A commanded address (PGN 65240) moves the node to a new address and claims it, if it names the node's NAME and an address from 0 to 251 other than the current one. Upstream only accepts it by transport protocol with exactly nine bytes, and only in `.node` mode, including during an address claim.
- Product or configuration information that can't be sent when asked for (a group function request during the address claim, or a transport protocol reply while another transfer is going) is sent again later, broadcast and without transport protocol: 187 ms plus 8 ms (product) or 10 ms (configuration) for each unit of the device's address, so devices don't retry together.
- `ParseMessages` sends pending messages, then handles received frames, then the heartbeat; `NodeEngine.receive(_:at:)` keeps that order.

### Several devices

A node can host several devices, as upstream's `SetDeviceCount` allows. Each has its own address, NAME, product information (falling back to the first device's), PGN lists, fast-packet sequence counters, address claim, transport protocol session and heartbeat. They share the transport, the reassembly buffers and the configuration information. A device moving to a new address skips its siblings' addresses. Broadcast ISO requests, group functions and commanded addresses go to every device in turn, and addressed ones, like transport protocol sessions, to the device at that address. The ISO request handler is told which device a request is for, and the device list asks from the first device.

### Not ported

- `ReadResetAddressChanged`, `ReadResetDeviceInformationChanged`: read `Node.address` and `Node.name` instead.

## Group functions

| Upstream | Swift |
|---|---|
| `tN2kGroupFunctionCode`, `tN2kGroupFunctionPGNErrorCode`, `tN2kGroupFunctionTransmissionOrPriorityErrorCode`, `tN2kGroupFunctionParameterErrorCode` | `GroupFunction.Code`, `.PGNError`, `.TransmissionError`, `.ParameterError` |
| `SetStartAcknowledge`, `AddAcknowledgeParameter`, `ChangePNGErrorCode`, `ChangeTransmissionOrPriorityErrorCode`, `SendAcknowledge` | `GroupFunction.Acknowledgement` |
| `SetStartReadReply`, `SetStartWriteReply` | `GroupFunction.startReply(_:pgn:proprietary:uniqueID:selectionPairCount:parameterPairCount:)` |
| `Parse`, `ParseRequestParams`, `ParseCommandParams`, `ParseAcknowledgeParams`, `ParseReadOrWriteParams`, `StartParse…Parameters` | `GroupFunction.Request` and its `requestParameters`, `commandParameters`, `acknowledgementParameters`, `readOrWriteParameters`, `pairs` |
| `AddGroupFunctionHandler`, `RemoveGroupFunctionHandler`, subclasses of `tN2kGroupFunctionHandler` | `Node.setGroupFunctionHandler(_:for:)` with a `Node.GroupFunctionHandler` closure, which returns `nil` where a subclass calls the base class |
| `GetRequestGroupFunctionTransmissionOrPriorityErrorCode` | `GroupFunction.transmissionError(interval:offset:intervalLimits:maxOffset:)` |
| `tNMEA2000::HandleGroupFunction`, `RespondGroupFunction`, `tN2kGroupFunctionHandler` | `NodeEngine.handleGroupFunction(_:at:)` |
| `tN2kGroupFunctionHandlerForPGN60928`, `…126464`, `…126993`, `…126996`, `…126998` | `NodeEngine+GroupFunctions.swift` |
| `SetDeviceInformationInstances`, `SetInstallationDescription1/2`, `SetHeartbeatIntervalAndOffset` | changes `Node.name`, `Node.configurationInformation` and the heartbeat schedule |

### Kept upstream behaviour

- Group functions are handled in `.node` mode, when sent to the node or broadcast. Commands, reads and writes that are broadcast are ignored, as are acknowledgements and read and write replies.
- A request for a PGN without its own handler is acknowledged: "PGN not supported" if the node doesn't transmit it, "temporarily not available" if it does, or "transmission interval not supported" for an interval or offset that isn't a special value. A command is acknowledged likewise, with "not supported" for a priority setting other than 8, 9 or 15. Reads and writes get "not supported". Nothing is sent for a broadcast request.
- Requests for 60928, 126464, 126996 and 126998 may filter on the PGN's fields. If every field matches, the node sends the PGN: an address claim 2 ms later, its PGN lists, or its product or configuration information, by transport protocol if the request came that way. Otherwise an addressed request is acknowledged field by field. An unknown field stops the parsing, and the fields after it are answered "temporarily unable to comply". A broadcast request stops at the first mismatch. Once a field has failed, upstream reports every later string field as out of range too.
- A command for 60928 sets the device instance (lower and upper) and system instance, and the node claims its address again 2 ms later. A command for 126998 sets the installation descriptions. In both, a field the handler doesn't know isn't skipped, so later pairs are read from the wrong place, and the 60928 command never reports an unsupported priority.
- A request for 126993 with an interval from 1 to 60 seconds and an offset up to 60 seconds (in 10 ms units) changes the heartbeat schedule and sends a heartbeat at once with sequence number `0xff`. An interval of 0 is refused, and `0xfffffffe` restores 60 seconds. A command for 126993 is answered "PGN not supported".
- Requests for both PGN lists by transport protocol send only the transmit list, because the node sends one transport protocol message at a time.

### Divergences

| Upstream | Swift | Why |
|---|---|---|
| The 126996 handler compares the software version, model version and serial code filters with the model ID | Compares each with its own field | Upstream answers "out of range" to a matching filter. **Changes the frames sent** for those requests. |

### Application handlers

An application answers group functions for its own PGNs with `Node.setGroupFunctionHandler(_:for:)`. Handlers for a PGN come first, then one for every PGN, then the node's own answers; a handler returns `nil` to leave a function to them. Upstream tries its handlers in the order they were added, with its built-in handlers added when the node opens, so this matches upstream for handlers added before opening.

## Device list

| Upstream | Swift |
|---|---|
| `tN2kDeviceList` | `DeviceList`, a value type driven by `handle(_:at:sending:)`; `Node(discoversDevices: true)` keeps one in `Node.deviceList` |
| `tN2kDeviceList::tInternalDevice`, `tNMEA2000::tDevice` | `DeviceList.Device` |
| `FindDeviceBySource`, `FindDeviceByName`, `FindDeviceByIDs`, `FindDeviceByProduct` | `DeviceList[source:]`, `device(named:)`, `device(manufacturerCode:uniqueNumber:)`, `device(manufacturerCode:productCode:after:)` |
| `Count`, `ReadResetIsListUpdated`, `GetDeviceLastMessageTime` | `count`, `resetUpdated()`, `Device.lastMessageTime` |

### Kept upstream behaviour

- A device is added when it claims its address, or when the list first hears from it and its request for the device's NAME goes out. A request that can't be sent (in listen-only mode, or while the node claims its address) adds nothing.
- Requests are paced by traffic: each message from a device other than a claim or one of the replies lets the list make at most one request. The list asks for the NAME of the device just heard (up to 20 times), then for each device's product information, configuration information and PGN lists in turn, one kind at a time, in address order. Each is asked at most four times, a second apart, starting a second after the device was added. Configuration information is asked more than a second apart, because upstream compares with `>`.
- A device that claims a different address keeps its details. A different device claiming an address moves the old one to the first free index, and the list asks every device to claim again.
- The list sees each message after the application's handler, so its requests follow any replies the node sends.
