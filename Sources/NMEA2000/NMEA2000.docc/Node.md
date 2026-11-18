# ``NMEA2000/Node``

## Topics

### Creating a node

- ``init(transport:configuration:clock:)``
- ``Configuration``
- ``Device``
- ``DeviceID``
- ``Mode``
- ``mode``

### Running the node

- ``run()``
- ``isOpen``
- ``isReady(_:)``
- ``waitUntilReady(_:)``
- ``events(bufferingPolicy:)``
- ``Event``

### Receiving messages

- ``messages(of:includingSent:bufferingPolicy:)``
- ``messages(includingSent:bufferingPolicy:)``

### Sending messages

- ``send(_:priority:to:from:framing:)``
- ``send(_:from:)``
- ``isTransmitted(_:by:)``

### Inspecting the node's devices

- ``address``
- ``name``
- ``devices``
- ``deviceIDs``
- ``configurationInformation``

### Discovering other devices

- ``deviceList``

### Answering requests

- ``setISORequestHandler(_:)``
- ``ISORequestHandler``
- ``PGNRequest``
- ``setGroupFunctionHandler(_:for:)``
- ``GroupFunctionHandler``

### Sending network management messages

- ``sendAddressClaim(from:to:)``
- ``sendProductInformation(from:to:transportProtocol:)``
- ``sendConfigurationInformation(from:to:transportProtocol:)``
- ``sendPGNList(_:from:to:transportProtocol:)``
- ``sendHeartbeat(from:)``
- ``restartAddressClaim()``

### Changing the node's settings

- ``setHeartbeatInterval(_:offset:for:)``
- ``setInstances(deviceInstance:systemInstance:for:)``
- ``setProductInformation(_:for:)``
- ``setConfigurationInformation(_:)``
