# Getting started with NMEA2000

Run a node on a CAN bus, receive decoded messages and send your own.

## Overview

A ``Node`` is one device on an NMEA 2000 bus. You give it a connection to the bus and a
description of your device, run it, and then read the messages it receives and send messages
through it.

### Add the package

Add the package to your `Package.swift`, and the `NMEA2000` product to your target:

```swift
dependencies: [
    .package(url: "https://github.com/NathanDigital/swift-nmea2000.git", branch: "main"),
],
targets: [
    .target(name: "MyApp", dependencies: [
        .product(name: "NMEA2000", package: "swift-nmea2000"),
    ]),
]
```

### Describe your device

Every device on a bus identifies itself with a NAME, which a ``DeviceName`` holds, and with
product information. The NAME must differ from every other device's on the bus, so give each
unit you build its own unique number.

@Snippet(path: "GettingStarted", slice: "device")

The manufacturer code, device function and device class are numbers the NMEA assigns. The
values here are the original library's defaults, which describe a PC gateway.

### Create the node

Create the node from a ``CANTransport``, which carries CAN frames to and from your hardware,
and a ``Node/Configuration``. The package doesn't include a transport;
<doc:ImplementingACANTransport> shows how to write one.

@Snippet(path: "GettingStarted", slice: "node")

``Node/Configuration/node(_:configurationInformation:)`` makes a full node, which claims an
address and answers requests. A logger or display that never sends can use
``Node/Configuration/listenOnly`` instead.

### Run it, receive and send

``Node/run()`` opens the transport and runs until the bus closes or its task is cancelled, so
run it in a task of its own beside the tasks that use the node.

@Snippet(path: "GettingStarted", slice: "run")

A node can't send until it has claimed its address, which takes about half a second from when
the transport opens. ``Node/waitUntilReady(_:)`` waits for that.

``Node/messages(of:includingSent:bufferingPolicy:)`` delivers one type of parameter group.
To handle several, read every message with ``Node/messages(includingSent:bufferingPolicy:)``
and decode each one; see <doc:DecodingAndEncodingMessages>.

### Units and missing values

Values are in SI units, as in the original library: metres per second, radians, kelvin and
pascals. Latitude and longitude are in degrees. Each property's documentation states its unit.

A device that has no value for a field sends "not available". Those fields are `Optional`,
and `nil` means not available.

## See Also

- <doc:ImplementingACANTransport>
- <doc:DecodingAndEncodingMessages>
