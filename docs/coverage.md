# Upstream coverage

This port aims to cover everything upstream's library does. This page tracks upstream's public API, file by file, against the port. The detailed mappings live in the other docs; this is the checklist.

Status: **done**, **to do**, or **by design** where the Swift API covers the need differently and the row says how. Upstream API that only exists because of the Arduino run loop, its stream classes or compile-time configuration is covered by Swift's own idioms rather than ported.

## `NMEA2000.h` (`tNMEA2000`)

| Upstream | Swift | Status |
|---|---|---|
| `SetMode`, `SetN2kSource`, `SetDeviceCount`, `SetDeviceInformation`, `SetProductInformation`, `SetConfigurationInformation`, `ExtendTransmitMessages`, `ExtendReceiveMessages` (before opening) | `Node(...)`, `Node.Device` | done |
| `Open`, `ParseMessages`, `IsOpen` | `Node.run()`, `Node.isOpen` | done |
| `SetOnOpen` | `Node.events()` (`.opened`) | done |
| `SendMsg(msg, DeviceIndex)` | `Node.send(_:from:)` | done |
| `SetMsgHandler`, `AttachMsgHandler`, `DetachMsgHandler` | `Node.messages()` | done; by design for per-PGN handlers: filter the sequence |
| `SetISORqstHandler` | `Node.setISORequestHandler(_:)` | done |
| `AddGroupFunctionHandler`, `RemoveGroupFunctionHandler`, `tN2kGroupFunctionHandler` | `Node.setGroupFunctionHandler(_:for:)`, `GroupFunction` | done |
| `SendIsoAddressClaim`, `SendProductInformation`, `SendConfigurationInformation`, `SendTxPGNList`, `SendRxPGNList`, `SendHeartbeat` (on demand) | `Node.sendAddressClaim`, `sendProductInformation`, `sendConfigurationInformation`, `sendPGNList`, `sendHeartbeat` | done; by design for `SendIsoAddressClaim`'s delay: wait before calling |
| `SetHeartbeatIntervalAndOffset`, `GetHeartbeatInterval`, `GetHeartbeatOffset` (at run time) | `Node.setHeartbeatInterval(_:offset:for:)`, `Node.devices` | done |
| `SetDeviceInformationInstances`, `SetInstallationDescription1/2`, `SetProductInformation`, `SetConfigurationInformation` (at run time) | `Node.setInstances`, `setProductInformation`, `setConfigurationInformation` | done |
| `ReadResetAddressChanged`, `ReadResetDeviceInformationChanged`, `ReadResetInstallationDescriptionChanged` | `Node.events()` | done |
| `Restart` | `Node.restartAddressClaim()` | done |
| `GetN2kSource`, `GetDeviceInformation`, `GetProductInformation` and its getters, `GetManufacturerInformation`, `GetInstallationDescription1/2`, `IsTxPGN` | `Node.devices`, `Node.configurationInformation`, `Node.isTransmitted(_:by:)` | done |
| `SetForwardStream`, `SetForwardType`, `EnableForward`, `SetForwardOwnMessages` | `Node.messages(includingSent:)`, with `Actisense.encode` or `Message.description` for the output format | done |
| `SetForwardSystemMessages`, `SetForwardOnlyKnownMessages` | | by design: filter the sequence |
| `SetDebugMode` (`dm_ClearText`, `dm_Actisense`) | | by design: a `CANTransport` that prints or encodes frames instead of sending them |
| `SetHandleOnlyKnownMessages`, `SetSingleFrameMessages`, `SetFastPacketMessages`, `Extend…Messages` | `Node(handlesOnlyKnownMessages:catalog:)`, `PGNCatalog` | done |
| `SetN2kCANMsgBufSize` | `Node(bufferCount:)` | done |
| `SetN2kCANSendFrameBufSize`, `SetN2kCANReceiveFrameBufSize` | `CANTransport` | by design: the transport buffers and suspends `send` when full |
| Priority `0x80` and up sends a fast-packet PGN in one frame | `Message.forcesSingleFrame` | done |
| `IsBroadcast`, `IsProprietaryMessage` and the other PGN classifiers | `Message.broadcastAddress`, `PGNCatalog` | done |
| Address claim, ISO requests, heartbeat, transport protocol, commanded address, group function defaults, pending resends | `NodeEngine` | done |

## Other files

| Upstream | Swift | Status |
|---|---|---|
| `N2kMsg.h` field helpers, `tN2kMsg` | `Message`, `MessageReader`, `MessageWriter` | done |
| `tN2kMsg::Print`, `PrintBuf` | `Message.description` | done |
| `tN2kMsg::SendInActisenseFormat`, `tActisenseReader` | `Actisense`, `ActisenseDecoder` | done; by design for `GetMessageFromStream(ReadOut: false)`, which leaves bytes in an Arduino stream for another reader: split shared input before decoding |
| `N2kToSeasmart`, `SeasmartToN2k` | `Seasmart` | done |
| `N2kMessages.h/.cpp` | `Sources/NMEA2000/PGNs/` | done |
| `N2kTypes.h` | `Sources/NMEA2000/Types/` | done |
| `N2kMessagesEnumToStr.h` | `CustomStringConvertible` on every type | by design: the port's descriptions cover every value, where upstream's tables have gaps and errors (see `docs/types.md`) |
| `N2kGroupFunction.h`, `N2kGroupFunctionDefaultHandlers.h` | `GroupFunction` (codes, `Request` parsers, `Acknowledgement`, `startReply`), `NodeEngine+GroupFunctions.swift` (default handlers) | done; by design for `MatchRequestField`: compare values directly |
| `N2kDeviceList.h` | `DeviceList` | done |
| `N2kMaretron.h`, `N2kCZone.h` | `Sources/NMEA2000/Proprietary/` | done |
| `N2kTimer.h`: `tN2kScheduler`, `tN2kSyncScheduler`, `N2kIsTimeBefore`, `N2kHasElapsed` | | by design: Swift's `Clock` and `Task.sleep` schedule work; the node keeps upstream's timing internally |
| `N2kStream.h` | | by design: Swift has its own text and byte output; the gateway codecs return bytes |
| `NMEA2000_CAN.h`, `NMEA2000_CompilerDefns.h`, `N2kDef.h`, `NMEA2000StdTypes.h`, `RingBuffer.h` | `CANTransport`, Swift collections | by design: compile-time driver selection and fixed buffers aren't needed |
