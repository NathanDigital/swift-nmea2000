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
// "Frames" or "Node" so it can be filtered. Node cases print each event's time
// in milliseconds since the case started.

#include <algorithm>
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

// Node cases stamp events with the time since the case started.
bool timed = false;
uint32_t origin = 0;

void record(const std::string &event) {
  if (!timed) {
    events.push_back(event);
    return;
  }
  char stamp[16];
  snprintf(stamp, sizeof stamp, "t=%u ", unsigned(now - origin));
  events.push_back(stamp + event);
}

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
  int failedOpens = 0;  // How many times CANOpen fails before it succeeds.

 protected:
  bool CANSendFrame(unsigned long id, unsigned char len, const unsigned char *buf,
                    bool) override {
    char line[32];
    snprintf(line, sizeof line, "tx id=0x%08lx data=", id);
    record(line + bytes(buf, len));
    return true;
  }
  bool CANOpen() override {
    if (failedOpens == 0) return true;
    failedOpens--;
    return false;
  }
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
  record(line + bytes(m.Data, m.DataLen));
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
          uint8_t destination = 0xff, uint8_t first = 0, bool tp = false) {
  tN2kMsg m;
  m.SetPGN(pgn);
  m.Priority = priority;
  m.Destination = destination;
  for (int i = 0; i < count; i++) m.AddByte(uint8_t(first + i));
  m.SetIsTPMessage(tp);
  if (!node.SendMsg(m) && timed) record("send refused");
}

// Sends a message with the ISO transport protocol.
void sendTP(TestNode &node, unsigned long pgn, int count, uint8_t destination = 0xff) {
  send(node, pgn, count, 6, destination, 0, true);
}

// Transport protocol frames, from source 0x42 to a destination. A connection
// management frame carries a control byte, four bytes and the PGN.
const unsigned long TPCM = 0x18ec0042, TPDT = 0x18eb0042;
unsigned long tp(unsigned long base, uint8_t destination) { return base | destination << 8; }
std::vector<unsigned char> cm(uint8_t control, uint8_t a, uint8_t b, uint8_t c, uint8_t d,
                              unsigned long pgn) {
  return {control, a, b, c, d, uint8_t(pgn), uint8_t(pgn >> 8), uint8_t(pgn >> 16)};
}
std::vector<unsigned char> rts(int count, unsigned long pgn, uint8_t packets = 0) {
  if (packets == 0) packets = uint8_t((count + 6) / 7);
  return cm(16, uint8_t(count), uint8_t(count >> 8), packets, 0xff, pgn);
}
std::vector<unsigned char> bam(int count, unsigned long pgn) {
  return cm(32, uint8_t(count), uint8_t(count >> 8), uint8_t((count + 6) / 7), 0xff, pgn);
}
std::vector<unsigned char> cts(uint8_t packets, uint8_t next, unsigned long pgn) {
  return cm(17, packets, next, 0xff, 0xff, pgn);
}
// Data packet `sequence` of a payload of `count` bytes counting up from 0.
std::vector<unsigned char> dt(uint8_t sequence, int count) {
  std::vector<unsigned char> data = {sequence};
  for (int i = (sequence - 1) * 7; i < sequence * 7; i++) data.push_back(i < count ? uint8_t(i) : 0xff);
  return data;
}
// Receives data packets first to last of a payload of `count` bytes.
void dts(TestNode &node, uint8_t destination, int first, int last, int count) {
  for (int i = first; i <= last; i++) receive(node, tp(TPDT, destination), dt(i, count));
}

// A fast-packet frame: the sequence/frame byte followed by up to seven bytes.
std::vector<unsigned char> fp(unsigned char counter, std::vector<unsigned char> rest) {
  rest.insert(rest.begin(), counter);
  return rest;
}

// Starts a node case: sets the mode and address, and polls once at t=0.
void start(TestNode &node, tNMEA2000::tN2kMode mode, uint8_t source = 23) {
  node.SetMode(mode, source);
  node.SetMsgHandler(handler);
  timed = true;
  origin = now;
  node.ParseMessages();
}

// Polls the node every 10 ms until t milliseconds into the case, as a main
// loop calling ParseMessages would.
void until(TestNode &node, uint32_t t) {
  while (now - origin < t) {
    now += std::min<uint32_t>(10, t - (now - origin));
    node.ParseMessages();
  }
}

// The NAME upstream's node claims with by default: unique number 1,
// manufacturer 2046, function 130, class 25, industry group 4.
const uint64_t ownName = 0xc0328200ffc00001ULL;

// Receives an ISO address claim from a source, with the first count bytes of
// a NAME.
void claim(TestNode &node, uint8_t source, uint64_t name, int count = 8) {
  std::vector<unsigned char> data;
  for (int i = 0; i < count; i++) data.push_back(uint8_t(name >> (8 * i)));
  receive(node, 0x18eeff00 | source, data);
}

struct Case {
  const char *name;
  std::function<void(TestNode &)> run;
};

#define SENDS(name, ...) {"Frames send " name, [](TestNode &n) { open(n, tNMEA2000::N2km_NodeOnly); __VA_ARGS__; }}
#define NODE(name, ...) {"Node " name, [](TestNode &n) { __VA_ARGS__; }}
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

    // Opening and claiming an address.
    NODE("open", start(n, tNMEA2000::N2km_NodeOnly); until(n, 600)),
    NODE("open retries after a failure", {
      n.failedOpens = 1;
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 1400);
    }),
    NODE("discards frames while opening", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 100);
      receive(n, 0x09f80117, {1, 2, 3, 4, 5, 6, 7, 8});
      until(n, 200);
      receive(n, 0x09f80117, {1, 2, 3, 4, 5, 6, 7, 8});
    }),
    NODE("sends only after its address claim", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 190);
      send(n, 129025, 8, 2);
      until(n, 449);
      send(n, 129025, 8, 2);
      until(n, 450);
      send(n, 129025, 8, 2);
    }),
    NODE("keeps its address against a higher NAME", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      claim(n, 23, ownName + 1);
      send(n, 129025, 8, 2);
    }),
    NODE("moves on against a lower NAME", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      claim(n, 23, ownName - 1);
      send(n, 129025, 8, 2);
      until(n, 749);
      send(n, 129025, 8, 2);
      until(n, 750);
      send(n, 129025, 8, 2);
    }),
    NODE("changes device instance against its own NAME while claiming", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 300);
      claim(n, 23, ownName);
      until(n, 549);
      send(n, 129025, 8, 2);
      until(n, 550);
      send(n, 129025, 8, 2);
    }),
    NODE("moves on against its own NAME after claiming", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      claim(n, 23, ownName);
    }),
    NODE("ignores claims for other addresses", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      claim(n, 24, ownName - 1);
      claim(n, 254, ownName - 1);
    }),
    NODE("reclaims against a short claim", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      claim(n, 23, ownName - 1, 7);
    }),
    NODE("wraps from address 251 to 0", {
      start(n, tNMEA2000::N2km_NodeOnly, 251);
      until(n, 500);
      claim(n, 251, ownName - 1);
    }),
    NODE("gives up when every address is taken", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      // 250 conflicts move the node from 23 round to 21; print the last two.
      for (int i = 0; i < 250; i++) claim(n, n.GetN2kSource(), ownName - 1);
      events.clear();
      claim(n, 21, ownName - 1);
      claim(n, 22, ownName - 1);
      until(n, 800);
      send(n, 129025, 8, 2);
    }),
    NODE("gives up from address 0 at 251", {
      start(n, tNMEA2000::N2km_NodeOnly, 0);
      until(n, 500);
      // 250 conflicts move the node from 0 to 250; print the last two.
      for (int i = 0; i < 250; i++) claim(n, n.GetN2kSource(), ownName - 1);
      events.clear();
      claim(n, 250, ownName - 1);
      claim(n, 251, ownName - 1);
    }),
    NODE("sends from address 251", {
      start(n, tNMEA2000::N2km_NodeOnly, 251);
      until(n, 450);
      send(n, 129025, 8, 2);
    }),
    // Receiving with the ISO transport protocol. The node is at 23 (0x17).
    NODE("TP receives a broadcast", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0xff), bam(20, 126464));
      until(n, 550);
      dts(n, 0xff, 1, 1, 20);
      until(n, 600);
      dts(n, 0xff, 2, 3, 20);
    }),
    NODE("TP receives from a sender to this node", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0x17), rts(50, 126464));
      dts(n, 0x17, 1, 5, 50);
      dts(n, 0x17, 6, 8, 50);
    }),
    NODE("TP asks for as many packets as the message has, up to 5", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0x17), rts(20, 126464, 2));
      dts(n, 0x17, 1, 2, 20);
      receive(n, tp(TPCM, 0x17), rts(20, 126464, 0));
    }),
    NODE("TP listens in on a transfer to another node", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0x30), rts(20, 126464));
      dts(n, 0x30, 1, 3, 20);
    }),
    NODE("TP aborts a transfer with a packet out of sequence", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0x17), rts(20, 126464));
      dts(n, 0x17, 1, 1, 20);
      dts(n, 0x17, 3, 3, 20);
      dts(n, 0x17, 2, 2, 20);
    }),
    NODE("TP drops a broadcast with a packet out of sequence", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0xff), bam(20, 126464));
      dts(n, 0xff, 2, 3, 20);
    }),
    NODE("TP refuses a message too long for its buffer", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0x17), rts(223, 126464));
      receive(n, tp(TPCM, 0x17), rts(222, 126464));
      receive(n, tp(TPCM, 0xff), bam(223, 126996));
    }),
    NODE("TP refuses a transfer when every buffer is busy", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      for (unsigned long source = 1; source <= 5; source++)
        receive(n, 0x0df80500 | source, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      receive(n, tp(TPCM, 0x17), rts(20, 126464));
      until(n, 600);
      receive(n, tp(TPCM, 0x17), rts(20, 126464));
    }),
    NODE("TP keeps a slow transfer's buffer while packets arrive", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      // The transfer starts first, so it would be the oldest buffer at 650
      // if its packet at 590 didn't make it young again.
      receive(n, tp(TPCM, 0xff), bam(20, 126464));
      until(n, 510);
      for (unsigned long source = 1; source <= 4; source++)
        receive(n, 0x0df80500 | source, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      until(n, 590);
      dts(n, 0xff, 1, 1, 20);
      until(n, 650);
      receive(n, 0x0df80506, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      dts(n, 0xff, 2, 3, 20);
    }),
    NODE("TP keeps transfers and fast packets of one PGN apart", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0xff), bam(10, 126464));
      receive(n, 0x19ee0042 | 0xff00, fp(0x00, {9, 1, 2, 3, 4, 5, 6}));
      dts(n, 0xff, 1, 2, 10);
      receive(n, 0x19ee0042 | 0xff00, fp(0x01, {7, 8, 9}));
    }),
    NODE("TP doesn't answer in listen only mode", {
      start(n, tNMEA2000::N2km_ListenOnly);
      until(n, 500);
      receive(n, tp(TPCM, 0x17), rts(20, 126464));
      dts(n, 0x17, 1, 3, 20);
    }),
    NODE("TP doesn't answer while claiming", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 300);
      receive(n, tp(TPCM, 0x17), rts(20, 126464));
      dts(n, 0x17, 1, 3, 20);
    }),

    // Sending with the ISO transport protocol.
    NODE("TP sends a broadcast", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20);
      until(n, 700);
    }),
    NODE("TP sends a message of whole packets", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 14);
      until(n, 700);
    }),
    NODE("TP answers at address 251", {
      start(n, tNMEA2000::N2km_NodeOnly, 251);
      until(n, 500);
      receive(n, tp(TPCM, 0xfb), rts(10, 126464));
      dts(n, 0xfb, 1, 2, 10);
    }),
    NODE("TP sends to one device", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 50, 0x42);
      until(n, 510);
      receive(n, tp(TPCM, 0x17), cts(5, 1, 126464));
      until(n, 520);
      receive(n, tp(TPCM, 0x17), cts(5, 6, 126464));
      until(n, 530);
      receive(n, tp(TPCM, 0x17), cm(19, 50, 0, 8, 0xff, 126464));
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP sends one message at a time", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      until(n, 549);
      sendTP(n, 126464, 20, 0x42);
      until(n, 550);
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP gives up after 100 ms without a CTS", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 50, 0x42);
      receive(n, tp(TPCM, 0x17), cts(5, 1, 126464));
      until(n, 599);
      sendTP(n, 126464, 20, 0x42);
      until(n, 600);
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP waits when asked for no packets", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      receive(n, tp(TPCM, 0x17), cts(0, 1, 126464));
      // With no packets asked for, the next packet number doesn't matter.
      receive(n, tp(TPCM, 0x17), cts(0, 9, 126464));
      until(n, 590);
      receive(n, tp(TPCM, 0x17), cts(2, 1, 126464));
      receive(n, tp(TPCM, 0x17), cts(9, 3, 126464));
    }),
    NODE("TP ends a transfer on a CTS out of sequence", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      receive(n, tp(TPCM, 0x17), cts(2, 2, 126464));
      receive(n, tp(TPCM, 0x17), cts(2, 1, 126464));
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP ends a transfer on a CTS for another PGN", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      receive(n, tp(TPCM, 0x17), cts(2, 1, 126996));
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP ends a transfer on an abort", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      receive(n, tp(TPCM, 0x17), cm(255, 1, 0xff, 0xff, 0xff, 126464));
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP ignores controls for a broadcast", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20);
      receive(n, tp(TPCM, 0x17), cts(2, 1, 126464));
      receive(n, tp(TPCM, 0x17), cm(255, 1, 0xff, 0xff, 0xff, 126464));
      until(n, 650);
    }),
    NODE("TP ignores controls for other nodes", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      receive(n, tp(TPCM, 0x30), cts(2, 1, 126464));
      receive(n, tp(TPCM, 0x30), cm(255, 1, 0xff, 0xff, 0xff, 126464));
      sendTP(n, 126464, 20, 0x42);
    }),
    NODE("TP sends a short message in one frame", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      sendTP(n, 59904, 3, 0x42);
      sendTP(n, 59904, 8, 0x42);
      sendTP(n, 126464, 6, 0x42);
    }),
    NODE("TP needs a full node", {
      start(n, tNMEA2000::N2km_ListenAndSend);
      until(n, 500);
      sendTP(n, 126464, 20, 0x42);
      sendTP(n, 126464, 20);
    }),
    NODE("starts from address 14 without one", {
      start(n, tNMEA2000::N2km_NodeOnly, 254);
      until(n, 300);
    }),
    NODE("listen and node mode claims", start(n, tNMEA2000::N2km_ListenAndNode); until(n, 300)),
    NODE("listen only mode stays quiet", {
      start(n, tNMEA2000::N2km_ListenOnly);
      until(n, 500);
      claim(n, 23, ownName - 1);
      send(n, 129025, 8, 2);
    }),
    NODE("send only mode doesn't claim", {
      start(n, tNMEA2000::N2km_SendOnly);
      until(n, 200);
      send(n, 129025, 8, 2);
      claim(n, 23, ownName - 1);
    }),
    NODE("listen and send mode doesn't claim", {
      start(n, tNMEA2000::N2km_ListenAndSend);
      until(n, 200);
      send(n, 129025, 8, 2);
      claim(n, 23, ownName - 1);
    }),
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
    timed = false;
    c.run(node);
    printf("%s:\n", c.name);
    for (const std::string &e : events) printf("  %s\n", e.c_str());
  }
  return 0;
}
