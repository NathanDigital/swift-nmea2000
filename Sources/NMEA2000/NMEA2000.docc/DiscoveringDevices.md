# Discovering devices on the bus

Keep a list of the other devices on the bus, with their names and product information.

## Overview

A ``DeviceList`` follows the address claims on the bus to learn which devices are present,
and asks each one for its product information, configuration information and the PGNs it
sends and receives. It ports the original library's `tN2kDeviceList`.

### Turn discovery on

Set ``Node/Configuration/discoversDevices`` before you create the node. The list sends its
requests from the node's first device, so a listen-only node can't discover devices.

@Snippet(path: "DiscoveringDevices", slice: "configuration")

### Read the list

The node reports ``Node/Event/deviceListChanged`` each time the list changes. Read the
current list from ``Node/deviceList``.

@Snippet(path: "DiscoveringDevices", slice: "events")

A device's details arrive over several seconds, because the list spaces out its requests so
that it doesn't flood the bus. The optional properties of a ``DeviceList/Entry`` are `nil` until the
device has answered.

### Find a device

Look a device up by its address with ``DeviceList/subscript(address:)``, by its NAME with
``DeviceList/device(named:)``, or by its manufacturer and product codes with
``DeviceList/device(manufacturerCode:productCode:after:)``. Addresses change when devices
join the bus, so identify a device by its NAME and look up its address when you send to it.

## See Also

- ``DeviceName``
- ``ProductInformation``
- ``ConfigurationInformation``
