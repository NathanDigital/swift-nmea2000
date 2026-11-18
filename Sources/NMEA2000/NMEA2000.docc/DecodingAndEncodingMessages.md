# Decoding and encoding messages

Convert between messages and typed parameter groups, and define parameter groups of your own.

## Overview

A ``Message`` is what travels on the bus: a PGN, a priority, source and destination addresses,
and a payload of bytes. A ``ParameterGroup`` is the decoded payload for one PGN, as a Swift
value with a property for each field. <doc:ParameterGroups> lists the types by PGN.

### Convert one type

Every parameter group encodes itself with ``ParameterGroup/makeMessage(priority:destination:)``
and decodes a message with ``ParameterGroup/init(_:)``, which throws if the message has a
different PGN.

@Snippet(path: "DecodingMessages", slice: "typed")

A node does both for you: ``Node/send(_:priority:to:from:framing:)`` takes a parameter group,
and ``Node/messages(of:includingSent:bufferingPolicy:)`` delivers decoded ones.

### Decode any message

To handle several kinds of message, decode each with the type for its PGN.
``Message/decoded(using:)`` looks the type up in a ``ParameterGroupCatalog``, and returns `nil`
for a PGN the catalog doesn't have. The default catalog, ``ParameterGroupCatalog/standard``,
holds every standard parameter group in the library.

@Snippet(path: "DecodingMessages", slice: "catalog")

The Maretron parameter groups are in ``ParameterGroupCatalog/maretron``, which you can add
with ``ParameterGroupCatalog/adding(_:)``.

### Expect values you don't know

Devices newer than this library send values and fields it doesn't know, and decoding
tolerates them:

- Enumerated fields are structs conforming to ``WireEnumeration``, not Swift enums. A value
  without a name is kept in `rawValue` and sent back unchanged, so a `switch` over one needs a
  `default` case.
- A payload longer than the fields a type knows decodes, and the extra bytes are ignored.
- A payload shorter than the full field list decodes, and the missing fields are `nil`.

### Define a parameter group

To send or receive a PGN the library doesn't have, such as a manufacturer's proprietary one,
conform a type to ``ParameterGroup``. Read the fields from a ``MessageReader`` and write them
to a ``MessageWriter`` in the order they appear on the wire. The scaled methods, such as
``MessageReader/readInt16(resolution:)``, convert between the integer on the wire and a
`Double?`, and treat the "not available" value as `nil`.

@Snippet(path: "DecodingMessages", slice: "custom")

Add the type to a catalog to decode it with the others.

@Snippet(path: "DecodingMessages", slice: "custom-catalog")

A message longer than eight bytes is always sent as a fast packet. To receive one, the node
has to know that its PGN is a fast packet, so that it reassembles the frames: add the PGN to
``PGNCatalog/fastPacketPGNs`` in ``Node/Configuration/catalog`` before you create the node.
The proprietary PGNs 126720 and 130816 to 131071 are fast packets already.

## See Also

- <doc:ParameterGroups>
- <doc:FieldValueTypes>
