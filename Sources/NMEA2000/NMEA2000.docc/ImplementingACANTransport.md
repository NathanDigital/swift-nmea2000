# Implementing a CAN transport

Connect a node to your CAN hardware by conforming a type to the transport protocol.

## Overview

A ``Node`` doesn't talk to hardware. It sends and receives ``CANFrame`` values through a
``CANTransport``, which you implement for the CAN interface you have: SocketCAN on Linux, a
USB adapter's serial protocol, or a gateway that carries raw frames. The package doesn't
include a driver.

A transport has three jobs:

- ``CANTransport/open()`` opens the connection and returns the frames it receives from then
  on, as an `AsyncSequence`.
- ``CANTransport/send(_:)`` sends one frame, and suspends while the interface's transmit
  queue is full.
- ``CANTransport/close()`` closes the connection. It has a default implementation that does
  nothing.

### Write the transport

This transport joins two nodes in memory, which is useful in tests and shows the whole
protocol. Each end holds the stream of frames it receives and the continuation that feeds the
other end.

@Snippet(path: "InMemoryTransport", slice: "transport")

A hardware transport has the same shape. A driver that delivers received frames from a
callback or a reading thread yields them to an `AsyncStream` continuation, and returns the
stream from ``CANTransport/open()``.

### Meet the node's expectations

The node relies on a few behaviours, which ``CANTransport`` documents in full:

- The bus runs at 250 kbit/s, and every frame has a 29-bit extended identifier.
  ``CANFrame/id`` holds the identifier alone, without any flag bits your interface's frame
  format adds.
- The frame sequence ends when the connection closes, and when the task reading it is
  cancelled. That is how cancelling ``Node/run()`` stops the node.
- If ``CANTransport/open()`` throws, the node calls it again a second later, so it can be
  called more than once.
- A suspended ``CANTransport/send(_:)`` throws `CancellationError` when its task is
  cancelled.

### Run nodes on it

@Snippet(path: "InMemoryTransport", slice: "nodes")

## See Also

- ``CANTransport``
- ``CANFrame``
- ``CANIdentifier``
