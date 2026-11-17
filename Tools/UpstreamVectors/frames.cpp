// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.
//
// Frame-level harness: runs upstream's tNMEA2000 node against a fake CAN
// driver and a clock the cases control, and prints every CAN frame the node
// sends ("tx") and every message it delivers to its handler ("rx"). The Swift
// tests compare their frame layer against this output.
//
// Run it with scripts/upstream-vectors. Give each case a name that starts with
// "Frames" so it can be filtered.

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <deque>
#include <functional>
#include <string>
#include <vector>

#include "NMEA2000.h"

// The node's clock. The harness is built without the Linux timer, so upstream
// reads time from millis().
static uint32_t now = 1000;
extern "C" uint32_t millis() { return now; }

namespace {

std::vector<std::string> events;

std::string bytes(const unsigned char *buf, int len) {
  std::string s = "[";
  char hex[8];
  for (int i = 0; i < len; i++) {
    snprintf(hex, sizeof hex, i == 0 ? "0x%02x" : ", 0x%02x", buf[i]);
    s += hex;
  }
  return s + "]";
}

struct Frame {
  unsigned long id;
  std::vector<unsigned char> data;
};

class TestNode : public tNMEA2000 {
 public:
  std::deque<Frame> incoming;

 protected:
  bool CANSendFrame(unsigned long id, unsigned char len, const unsigned char *buf,
                    bool) override {
    char line[32];
    snprintf(line, sizeof line, "tx id=0x%08lx data=", id);
    events.push_back(line + bytes(buf, len));
    return true;
  }
  bool CANOpen() override { return true; }
  bool CANGetFrame(unsigned long &id, unsigned char &len, unsigned char *buf) override {
    if (incoming.empty()) return false;
    Frame f = incoming.front();
    incoming.pop_front();
    id = f.id;
    len = f.data.size();
    memcpy(buf, f.data.data(), len);
    return true;
  }
};

void handler(const tN2kMsg &m) {
  char line[96];
  snprintf(line, sizeof line, "rx pgn=%lu priority=%u source=%u destination=%u data=", m.PGN,
           m.Priority, m.Source, m.Destination);
  events.push_back(line + bytes(m.Data, m.DataLen));
}

// Opens the node and lets its address claim finish, then forgets the frames
// that produced.
void open(TestNode &node, tNMEA2000::tN2kMode mode, uint8_t source = 23) {
  node.SetMode(mode, source);
  node.SetMsgHandler(handler);
  for (int i = 0; i < 60; i++) {
    node.ParseMessages();
    now += 10;
  }
  events.clear();
}

void receive(TestNode &node, unsigned long id, std::vector<unsigned char> data) {
  node.incoming.push_back({id, data});
  node.ParseMessages();
}

void send(TestNode &node, unsigned long pgn, int count, uint8_t priority = 6,
          uint8_t destination = 0xff, uint8_t first = 0) {
  tN2kMsg m;
  m.SetPGN(pgn);
  m.Priority = priority;
  m.Destination = destination;
  for (int i = 0; i < count; i++) m.AddByte(uint8_t(first + i));
  node.SendMsg(m);
}

// A fast-packet frame: the sequence/frame byte followed by up to seven bytes.
std::vector<unsigned char> fp(unsigned char counter, std::vector<unsigned char> rest) {
  rest.insert(rest.begin(), counter);
  return rest;
}

struct Case {
  const char *name;
  std::function<void(TestNode &)> run;
};

#define SENDS(name, ...) {"Frames send " name, [](TestNode &n) { open(n, tNMEA2000::N2km_NodeOnly); __VA_ARGS__; }}
#define RECEIVES(name, ...) {"Frames receive " name, [](TestNode &n) { open(n, tNMEA2000::N2km_ListenOnly); __VA_ARGS__; }}

const std::vector<Case> cases = {
    // Sending.
    SENDS("single frame", send(n, 129025, 8, 2)),
    SENDS("short single frame", send(n, 127245, 3, 2)),
    SENDS("unknown PGN single frame", send(n, 65300, 8, 7)),
    SENDS("fast packet", send(n, 129029, 43, 3)),
    SENDS("fast packet of 6 bytes", send(n, 129029, 6)),
    SENDS("fast packet of 7 bytes", send(n, 129029, 7)),
    SENDS("fast packet of 13 bytes", send(n, 129029, 13)),
    SENDS("fast packet of 14 bytes", send(n, 129029, 14)),
    SENDS("fast packet of 223 bytes", send(n, 129029, 223)),
    SENDS("empty single frame", send(n, 127245, 0, 2)),
    SENDS("long single-frame PGN", send(n, 127250, 10, 2)),
    SENDS("proprietary fast packet", send(n, 126720, 10); send(n, 130816, 10)),
    SENDS("addressed", send(n, 59904, 3, 6, 0x42)),
    SENDS("addressed fast packet", send(n, 126208, 10, 3, 0x42)),
    SENDS("broadcast PGN ignores destination", send(n, 129025, 8, 2, 0x42)),
    SENDS("invalid PDU1 PGN", send(n, 59905, 3)),
    SENDS("PGN zero", send(n, 0, 3)),
    SENDS("sequence counter wraps", for (int i = 0; i < 9; i++) send(n, 129029, 7, 3, 0xff, i)),
    SENDS("sequence counters per PGN", {
      // The default transmit list has four fast-packet PGNs, so the first four
      // fast-packet PGNs sent get their own counters and the rest share one.
      unsigned long pgns[] = {129029, 129038, 129039, 129040, 129041, 129794};
      for (int round = 0; round < 2; round++)
        for (unsigned long pgn : pgns) send(n, pgn, 7);
    }),
    SENDS("first PDU2 PGN", send(n, 61440, 8, 6, 0x42)),
    SENDS("widest PGN", send(n, 0x3ffff, 3)),
    {"Frames send from address 251", [](TestNode &n) {
       open(n, tNMEA2000::N2km_NodeOnly, 251);
       send(n, 129025, 8, 2);
     }},
    SENDS("listen only sends nothing", {
      TestNode quiet;
      open(quiet, tNMEA2000::N2km_ListenOnly);
      send(quiet, 129025, 8, 2);
    }),

    // Receiving.
    RECEIVES("single frame", receive(n, 0x09f80117, {1, 2, 3, 4, 5, 6, 7, 8})),
    RECEIVES("short single frame", receive(n, 0x09f10d17, {1, 2, 3})),
    RECEIVES("addressed", receive(n, 0x18ea4217, {0x10, 0xf0, 0x01})),
    RECEIVES("fast packet", {
      receive(n, 0x0df80517, fp(0x40, {15, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80517, fp(0x41, {7, 8, 9, 10, 11, 12, 13}));
      receive(n, 0x0df80517, fp(0x42, {14, 15, 0xff, 0xff, 0xff, 0xff, 0xff}));
    }),
    RECEIVES("fast packet with short last frame", {
      receive(n, 0x0df80517, fp(0x20, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80517, fp(0x21, {7, 8, 9}));
    }),
    RECEIVES("fast packet in one frame", receive(n, 0x0df80517, fp(0x00, {4, 1, 2, 3, 4, 0xff, 0xff}))),
    RECEIVES("fast packet with a lost frame", {
      receive(n, 0x0df80517, fp(0x40, {15, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80517, fp(0x42, {14, 15, 0xff, 0xff, 0xff, 0xff, 0xff}));
      receive(n, 0x0df80517, fp(0x41, {7, 8, 9, 10, 11, 12, 13}));
    }),
    RECEIVES("fast packet restarted", {
      receive(n, 0x0df80517, fp(0x40, {15, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80517, fp(0x60, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80517, fp(0x61, {7, 8, 9}));
    }),
    RECEIVES("orphan continuation frame", receive(n, 0x0df80517, fp(0x41, {7, 8, 9, 10, 11, 12, 13}))),
    RECEIVES("interleaved sources", {
      receive(n, 0x0df80517, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80518, fp(0x20, {9, 11, 12, 13, 14, 15, 16}));
      receive(n, 0x0df80518, fp(0x21, {17, 18, 19}));
      receive(n, 0x0df80517, fp(0x01, {7, 8, 9}));
    }),
    RECEIVES("too many open fast packets", {
      for (unsigned long source = 1; source <= 6; source++)
        receive(n, 0x0df80500 | source, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      for (unsigned long source = 1; source <= 6; source++)
        receive(n, 0x0df80500 | source, fp(0x01, {7, 8, uint8_t(source)}));
    }),
    RECEIVES("stale buffer reused after 100 ms", {
      for (unsigned long source = 1; source <= 5; source++) {
        receive(n, 0x0df80500 | source, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
        now += 10;
      }
      // The oldest buffer is 99 ms old: not reused yet. At 100 ms it is.
      now += 49;
      receive(n, 0x0df80506, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      now += 1;
      receive(n, 0x0df80506, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80506, fp(0x01, {7, 8, 6}));
      receive(n, 0x0df80501, fp(0x01, {7, 8, 1}));
      receive(n, 0x0df80502, fp(0x01, {7, 8, 2}));
    }),
    RECEIVES("busy buffers kept for 99 ms", {
      for (unsigned long source = 1; source <= 5; source++) {
        receive(n, 0x0df80500 | source, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
        now += 10;
      }
      now += 49;
      receive(n, 0x0df80506, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80506, fp(0x01, {7, 8, 6}));
      receive(n, 0x0df80501, fp(0x01, {7, 8, 1}));
    }),
    RECEIVES("fast packet longer than the buffer", {
      receive(n, 0x0df80517, fp(0x00, {230, 1, 2, 3, 4, 5, 6}));
      for (unsigned char i = 1; i < 32; i++)
        receive(n, 0x0df80517, fp(i, {7, 7, 7, 7, 7, 7, 7}));
    }),
    RECEIVES("first PDU2 PGN", receive(n, 0x18f00017, {1, 2, 3, 4, 5, 6, 7, 8})),
    RECEIVES("empty fast packet", receive(n, 0x0df80517, {0x00, 0x00})),
    RECEIVES("busy buffers half a clock cycle later", {
      // Buffers that look more than half the 32-bit clock old count as newer,
      // so they're never taken over.
      for (unsigned long source = 1; source <= 5; source++)
        receive(n, 0x0df80500 | source, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      now += 0x7fffffff;
      receive(n, 0x0df80506, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x0df80506, fp(0x01, {7, 8, 6}));
      receive(n, 0x0df80501, fp(0x01, {7, 8, 1}));
    }),
    RECEIVES("unknown PGN", receive(n, 0x1cff1417, {1, 2, 3, 4, 5, 6, 7, 8})),
    RECEIVES("long unknown PGN frame", receive(n, 0x1cff1417, {1, 2, 3})),
    RECEIVES("proprietary fast packet", {
      receive(n, 0x19ff0017, fp(0x00, {8, 1, 2, 3, 4, 5, 6}));
      receive(n, 0x19ff0017, fp(0x01, {7, 8}));
    }),
    RECEIVES("only known messages", {
      n.SetHandleOnlyKnownMessages(true);
      receive(n, 0x1cff1417, {1, 2, 3, 4, 5, 6, 7, 8});
      receive(n, 0x09f80117, {1, 2, 3, 4, 5, 6, 7, 8});
    }),
    RECEIVES("bits above the 29-bit identifier", receive(n, 0x89f80117, {1, 2, 3, 4, 5, 6, 7, 8})),
    RECEIVES("PDU2 with data page", receive(n, 0x0bf80117, {1, 2, 3, 4, 5, 6, 7, 8})),
};

}  // namespace

int main(int argc, char **argv) {
  for (const Case &c : cases) {
    bool selected = argc < 2;
    for (int i = 1; i < argc && !selected; i++) selected = strstr(c.name, argv[i]) != nullptr;
    if (!selected) continue;
    // The clock only moves forward across cases: upstream's 64-bit timer
    // counts a backwards step as a 32-bit rollover.
    TestNode node;
    events.clear();
    c.run(node);
    printf("%s:\n", c.name);
    for (const std::string &e : events) printf("  %s\n", e.c_str());
  }
  return 0;
}
