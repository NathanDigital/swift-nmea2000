# Using gateway formats

Exchange messages with serial and network gateways in the Actisense and SeaSmart formats.

## Overview

Gateways carry whole NMEA 2000 messages over a serial port or a network connection, so a
program can read a bus without a CAN interface. The library converts messages to and from two
gateway formats. The codecs do no I/O: you read and write the serial port or socket, and pass
the bytes through them.

### Actisense

``Actisense`` is the binary format of the Actisense NGT-1 and many PC programs.
``Actisense/encode(_:)`` returns the bytes for one message. An ``Actisense/Decoder`` takes
bytes as they arrive, in chunks of any size, and returns each message once it is complete.

@Snippet(path: "GatewayFormats", slice: "actisense")

### SeaSmart

``Seasmart`` is the `$PCDIN` sentence, which carries a message as NMEA 0183 text. The
sentence doesn't carry the priority or the destination, so a decoded message has the default
priority and is addressed to every device.

@Snippet(path: "GatewayFormats", slice: "seasmart")

### Bridge a gateway and a node

A gateway node receives every message, and sends from an address it doesn't claim, so
create it with ``Node/Configuration/listenAndSend(address:)``. Read
``Node/messages(includingSent:bufferingPolicy:)`` with `includingSent: true` to include the
messages the node itself sends.

@Snippet(path: "GatewayBridge", slice: "node")

To forward the bus to the gateway, encode each message and write its bytes. To forward the
other way, decode the gateway's bytes and pass each message to ``Node/send(_:from:)``, which
sends it from the node's address. Here `serialPort` stands for your serial port or socket.

@Snippet(path: "GatewayBridge", slice: "bridge")

## See Also

- ``GatewayError``
