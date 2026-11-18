// snippet.hide
// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
// snippet.show
// Converts messages to and from the Actisense and SeaSmart gateway formats.
// Run it with `scripts/linux-swift run GatewayFormats`.

import NMEA2000

let message = WindData(reference: .apparent, windSpeed: 5.2, windAngle: 0.61).makeMessage()

// snippet.actisense
// Encode a message to write to a serial port.
let bytes = try Actisense.encode(message)

// Feed a decoder the bytes read from a serial port, in any chunks. It
// returns each message once its last byte is in.
var decoder = Actisense.Decoder()
for chunk in [bytes.prefix(5), bytes.dropFirst(5)] {
  for received in decoder.decode(chunk, at: .zero) {
    print("Actisense", received)
  }
}
// snippet.end

// snippet.seasmart
// Encode a message as a $PCDIN sentence, and decode one.
let sentence = try Seasmart.encode(message)
let received = try Seasmart.decode(sentence)
print(sentence, received)
// snippet.end
