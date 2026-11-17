# Upstream coverage

This port aims to cover everything upstream's library does. This page tracks upstream's public API, file by file, against the port. The detailed mappings live in the other docs; this is the checklist.

Status: **done**, **to do**, or **by design** where the Swift API covers the need differently and the row says how.

## `NMEA2000.h` (`tNMEA2000`)

| Upstream | Swift | Status |
|---|---|---|
| `SetMode`, `SetN2kSource`, `SetDeviceCount`, `SetDeviceInformation`, `SetProductInformation`, `SetConfigurationInformation`, `ExtendTransmitMessages`, `ExtendReceiveMessages` (before opening) | `Node(...)`, `Node.Device` | done |
| `Open`, `ParseMessages`, `IsOpen` | `Node.run()` | done; `isOpen` to do |
| `SetOnOpen` | | to do |
| `SendMsg(msg, DeviceIndex)` | `Node.send(_:from:)` | done |
| `SetMsgHandler`, `AttachMsgHandler`, `DetachMsgHandler` | `Node.messages()` | done; a per-PGN variant to do |
| `SetISORqstHandler` | `Node.setISORequestHandler(_:)` | done |
| `AddGroupFunctionHandler`, `RemoveGroupFunctionHandler`, `tN2kGroupFunctionHandler` | | to do |
| `SendIsoAddressClaim`, `SendProductInformation`, `SendConfigurationInformation`, `SendTxPGNList`, `SendRxPGNList`, `SendHeartbeat` (on demand) | | to do |
| `SetHeartbeatIntervalAndOffset`, `GetHeartbeatInterval`, `GetHeartbeatOffset` (at run time) | | to do |
| `SetDeviceInformationInstances`, `SetInstallationDescription1/2`, `SetProductInformation`, `SetConfigurationInformation` (at run time) | | to do |
| `ReadResetAddressChanged`, `ReadResetDeviceInformationChanged`, `ReadResetInstallationDescriptionChanged` | | to do |
| `Restart` | | to do |
| `GetN2kSource`, `GetDeviceInformation`, `GetProductInformation` and its getters, `GetManufacturerInformation`, `GetInstallationDescription1/2`, `IsTxPGN` | `Node.devices`, `Node.configurationInformation` | done; `IsTxPGN` to do |
| `SetForwardStream`, `SetForwardType`, `EnableForward`, `SetForwardSystemMessages`, `SetForwardOnlyKnownMessages`, `SetForwardOwnMessages` | | to do |
| `SetDebugMode` (`dm_ClearText`, `dm_Actisense`) | | to do |
| `SetHandleOnlyKnownMessages`, `SetSingleFrameMessages`, `SetFastPacketMessages`, `Extend…Messages` | `Node(handlesOnlyKnownMessages:catalog:)`, `PGNCatalog` | done |
| `SetN2kCANMsgBufSize` | `MessageAssembler(bufferCount:)` | done; a `Node` parameter to do |
| `SetN2kCANSendFrameBufSize`, `SetN2kCANReceiveFrameBufSize` | `CANTransport` | by design: the transport buffers and suspends `send` when full |
| Priority `0x80` and up sends a fast-packet PGN in one frame | | to do |
| `IsBroadcast`, `IsProprietaryMessage` and the other PGN classifiers | `Message.broadcastAddress`, `PGNCatalog` | done |
| Address claim, ISO requests, heartbeat, transport protocol, commanded address, group function defaults, pending resends | `NodeEngine` | done |

## Other files

| Upstream | Swift | Status |
|---|---|---|
| `N2kMsg.h` field helpers, `tN2kMsg` | `Message`, `MessageReader`, `MessageWriter` | done |
| `tN2kMsg::Print`, `PrintBuf` | | to do |
| `tN2kMsg::SendInActisenseFormat`, `tActisenseReader` | `Actisense`, `ActisenseDecoder` | done; `GetMessageFromStream(ReadOut: false)` to do |
| `N2kToSeasmart`, `SeasmartToN2k` | `Seasmart` | done |
| `N2kMessages.h/.cpp` | `Sources/NMEA2000/PGNs/` | done |
| `N2kTypes.h` | `Sources/NMEA2000/Types/` | done |
| `N2kMessagesEnumToStr.h` | `CustomStringConvertible` on every type | by design: the port's descriptions cover every value, where upstream's tables have gaps and errors (see `docs/types.md`) |
| `N2kGroupFunction.h`, `N2kGroupFunctionDefaultHandlers.h` | `NodeEngine+GroupFunctions.swift` | defaults done; the public handler API to do |
| `N2kDeviceList.h` | `DeviceList` | done |
| `N2kMaretron.h`, `N2kCZone.h` | `Sources/NMEA2000/Proprietary/` | done |
| `N2kTimer.h`: `tN2kScheduler`, `tN2kSyncScheduler`, `N2kIsTimeBefore`, `N2kHasElapsed` | | to do |
| `N2kStream.h` | | by design: Swift has its own text and byte output; the gateway codecs return bytes |
| `NMEA2000_CAN.h`, `NMEA2000_CompilerDefns.h`, `N2kDef.h`, `NMEA2000StdTypes.h`, `RingBuffer.h` | `CANTransport`, Swift collections | by design: compile-time driver selection and fixed buffers aren't needed |
