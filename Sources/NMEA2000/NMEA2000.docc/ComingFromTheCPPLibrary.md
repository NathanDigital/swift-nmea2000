# Coming from the C++ library

Find the Swift counterpart of each part of Timo Lappalainen's NMEA2000 library.

## Overview

This package ports the [NMEA2000 library](https://github.com/ttlappalainen/NMEA2000) for C++.
The bytes on the bus are the same; the API is not a transliteration. Each type's documentation
names the upstream functions it ports, so searching for an upstream name such as
`SetN2kPGN129025` finds the Swift type.

| C++ | Swift |
|---|---|
| `tN2kMsg` | ``Message``, with ``MessageWriter`` and ``MessageReader`` for its fields |
| `SetN2kPGN…` / `ParseN2kPGN…` | One type for each PGN, listed in <doc:ParameterGroups> |
| `tN2k…` enums | Types conforming to ``WireEnumeration``, listed in <doc:FieldValueTypes> |
| `N2kDoubleNA`, `N2kUInt8NA` and the other "not available" values | `nil` |
| `tNMEA2000` | ``Node`` |
| `SetMode`, `SetDeviceInformation`, `SetProductInformation` and the other settings made before `Open` | ``Node/Configuration`` and ``Node/Device`` |
| `SetDeviceCount` and the `DeviceIndex` arguments | Several devices in a ``Node/Configuration``, and ``Node/DeviceID``; see <doc:HostingSeveralDevices> |
| `ParseMessages` in the main loop | ``Node/run()`` in a task |
| `SetMsgHandler`, `AttachMsgHandler` | ``Node/messages(includingSent:bufferingPolicy:)`` and ``Node/messages(of:includingSent:bufferingPolicy:)`` |
| `SendMsg` | ``Node/send(_:from:)`` and ``Node/send(_:priority:to:from:framing:)`` |
| A CAN driver class (`NMEA2000_CAN.h`) | A type conforming to ``CANTransport`` |
| `tN2kDeviceList` | ``DeviceList`` |
| `tN2kGroupFunctionHandler` | ``Node/setGroupFunctionHandler(_:for:)`` |
| `tActisenseReader`, `SendInActisenseFormat` | ``Actisense`` |
| `N2kToSeasmart`, `SeasmartToN2k` | ``Seasmart`` |

### Differences to expect

- **Units** are the same SI units as upstream.
- **Unknown enumerated values** are kept and sent back unchanged, where upstream's parsers
  cast them to the enum.
- **Decoders** follow what the wire format means. Where an upstream parser loses
  information, the Swift decoder doesn't; each such difference is noted on the type.
- **Errors** are thrown, where upstream's functions return `false`.

The complete mapping, file by file, and every deliberate difference are in the
[porting notes](https://github.com/NathanDigital/swift-nmea2000/tree/main/docs) in the
repository.
