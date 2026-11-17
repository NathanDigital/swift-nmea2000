# Gateway formats: upstream → Swift mapping

Upstream reads and writes gateway formats straight from and to streams (`N2kStream`). This port makes them pure codecs in `Sources/NMEA2000/Gateway/`: they turn messages into bytes and bytes into messages, and leave serial ports and sockets to the caller.

## Actisense

| Upstream | Swift |
|---|---|
| `tN2kMsg::SendInActisenseFormat` | `Actisense.encode(_:)` |
| `tActisenseReader`, `GetMessageFromStream`, `ParseMessages` | `ActisenseDecoder.decode(_:at:)` |
| `tActisenseReader::SetDefaultSource` (default 65) | `ActisenseDecoder(defaultSource:)` |
| `SetReadStream`, `SetMsgHandler` | not needed: feed the decoder bytes and use the messages it returns |

### Kept upstream behaviour

- A message is framed by DLE STX and DLE ETX, with every `0x10` inside doubled, including the checksum. The checksum makes the unescaped body sum to zero.
- The writer writes type `0x93` with the message's time stamp, and nothing for a message without a PGN or payload.
- The reader accepts types `0x93` (a received message) and `0x94` (a message sent to the gateway, which takes the default source and the current time). It drops a message whose length, checksum or payload length doesn't add up, or whose payload is longer than 223 bytes, and a body longer than 300 bytes. DLE STX inside a message starts a new one; DLE followed by anything else drops the message.

### Divergences

| Upstream | Swift | Why |
|---|---|---|
| `SendInActisenseFormat` counts its output with an 8-bit index, so a message longer than 255 bytes once escaped comes out corrupted | `Actisense.encode(_:)` writes the whole message | Upstream sends a broken frame. **Changes the bytes sent** for such messages. |
| The reader keeps the whole priority byte | Keeps its low three bits | `Message.priority` holds three bits, the width of the CAN priority field. |
| `GetMessageFromStream(ReadOut: false)` leaves bytes outside a message in the stream for another reader | Not ported | The decoder takes bytes it is given; split a shared stream before decoding. |
