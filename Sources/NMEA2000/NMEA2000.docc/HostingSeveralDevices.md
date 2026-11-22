# Hosting several devices

Run one node that appears on the bus as several devices.

## Overview

A unit that does two jobs, such as a temperature monitor and a battery monitor, can appear on
the bus as two devices over one CAN connection. Each device has its own address, NAME,
product information, PGN lists and heartbeat. They share the transport and the configuration
information. This ports the original library's `SetDeviceCount`.

### Describe each device

Give every device its own ``DeviceName``, with a different unique number, and the PGNs it
sends. A device without product information of its own uses the first device's.

@Snippet(path: "MultipleDevices", slice: "devices")

### Create the node

Pass the devices to ``Node/Configuration/init(mode:devices:configurationInformation:)``. A
``Node/DeviceID`` identifies a device by its position in that array.

@Snippet(path: "MultipleDevices", slice: "node")

### Send from a device

Each device claims its own address, so wait for the one you send from with
``Node/waitUntilReady(_:)``, and name it when you send. The methods that take a device use the
first one by default.

@Snippet(path: "MultipleDevices", slice: "send")

Requests addressed to one device are answered by that device, and broadcast requests by each
in turn. A handler set with ``Node/setISORequestHandler(_:)`` is told which device a request
is for in ``Node/PGNRequest/device``.

## See Also

- <doc:GettingStarted>
- ``Node/devices``
- ``Node/deviceIDs``
