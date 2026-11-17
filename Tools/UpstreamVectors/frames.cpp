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

#include "ActisenseReader.h"
#include "N2kDeviceList.h"
#include "Seasmart.h"
#include "N2kMessages.h"
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
  bool isFastPacket(unsigned long pgn) { return IsFastPacketPGN(pgn); }

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

// Polls the node every 10 ms (or `step`) until t milliseconds into the case,
// as a main loop calling ParseMessages would.
void until(TestNode &node, uint32_t t, uint32_t step = 10) {
  while (now - origin < t) {
    now += std::min<uint32_t>(step, t - (now - origin));
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

// An ISO request from 0x42 for a PGN, sent to a destination. A count other
// than 3 sends that many bytes instead.
void request(TestNode &node, uint8_t destination, unsigned long pgn, int count = 3) {
  std::vector<unsigned char> data = {uint8_t(pgn), uint8_t(pgn >> 8), uint8_t(pgn >> 16)};
  data.resize(count, 0xff);
  receive(node, 0x18ea0042 | destination << 8, data);
}

// Receives a commanded address (PGN 65240) from 0x42 by transport protocol
// broadcast: a NAME and a new address, plus `extra` more bytes.
void command(TestNode &node, uint64_t name, uint8_t address, int extra = 0) {
  std::vector<unsigned char> payload;
  for (int i = 0; i < 8; i++) payload.push_back(uint8_t(name >> (8 * i)));
  payload.push_back(address);
  payload.resize(9 + extra, 0x55);
  int count = payload.size();
  receive(node, tp(TPCM, 0xff), bam(count, 65240));
  for (int sequence = 1; (sequence - 1) * 7 < count; sequence++) {
    std::vector<unsigned char> data = {uint8_t(sequence)};
    for (int i = (sequence - 1) * 7; i < sequence * 7; i++) data.push_back(i < count ? payload[i] : 0xff);
    receive(node, tp(TPDT, 0xff), data);
  }
}

// Receives a group function (PGN 126208) from 0x42 as a fast packet, or by
// transport protocol: a BAM when broadcast, otherwise a request to send whose
// clear to send is ignored.
void groupFunction(TestNode &node, uint8_t destination, std::vector<unsigned char> payload,
                   bool useTP = false) {
  int count = payload.size();
  if (useTP) {
    receive(node, tp(TPCM, destination),
            destination == 0xff ? bam(count, 126208) : rts(count, 126208));
    for (int sequence = 1; (sequence - 1) * 7 < count; sequence++) {
      std::vector<unsigned char> data = {uint8_t(sequence)};
      for (int i = (sequence - 1) * 7; i < sequence * 7; i++) data.push_back(i < count ? payload[i] : 0xff);
      receive(node, tp(TPDT, destination), data);
    }
    return;
  }
  unsigned long id = 0x0ded0042 | destination << 8;
  std::vector<unsigned char> first = {0x00, uint8_t(count)};
  for (int i = 0; i < 6; i++) first.push_back(i < count ? payload[i] : 0xff);
  receive(node, id, first);
  for (int frame = 1; 6 + (frame - 1) * 7 < count; frame++) {
    std::vector<unsigned char> data = {uint8_t(frame)};
    for (int i = 6 + (frame - 1) * 7; i < 6 + frame * 7; i++) data.push_back(i < count ? payload[i] : 0xff);
    receive(node, id, data);
  }
}

// Group function payloads: the function code and PGN, then the rest.
std::vector<unsigned char> gf(uint8_t code, unsigned long pgn, std::vector<unsigned char> rest) {
  std::vector<unsigned char> payload = {code, uint8_t(pgn), uint8_t(pgn >> 8), uint8_t(pgn >> 16)};
  payload.insert(payload.end(), rest.begin(), rest.end());
  return payload;
}
// A request: transmission interval, offset, then parameter pairs.
std::vector<unsigned char> gfRequest(unsigned long pgn, uint32_t interval, uint16_t offset,
                                     uint8_t pairs, std::vector<unsigned char> fields = {}) {
  std::vector<unsigned char> rest = {uint8_t(interval), uint8_t(interval >> 8), uint8_t(interval >> 16),
                                     uint8_t(interval >> 24), uint8_t(offset), uint8_t(offset >> 8), pairs};
  rest.insert(rest.end(), fields.begin(), fields.end());
  return gf(0, pgn, rest);
}
// A command: priority setting, then parameter pairs.
std::vector<unsigned char> gfCommand(unsigned long pgn, uint8_t priority, uint8_t pairs,
                                     std::vector<unsigned char> fields = {}) {
  std::vector<unsigned char> rest = {uint8_t(0xf0 | priority), pairs};
  rest.insert(rest.end(), fields.begin(), fields.end());
  return gf(1, pgn, rest);
}
// A variable-length ASCII string field.
std::vector<unsigned char> varStr(const char *text) {
  std::vector<unsigned char> field = {uint8_t(strlen(text) + 2), 1};
  for (const char *c = text; *c; c++) field.push_back(*c);
  return field;
}
std::vector<unsigned char> operator+(std::vector<unsigned char> a, const std::vector<unsigned char> &b) {
  a.insert(a.end(), b.begin(), b.end());
  return a;
}

// Receives a message built with upstream's encoders, from its source: one
// frame, or a fast packet.
void inject(TestNode &node, tN2kMsg m, unsigned char source) {
  unsigned long id = (unsigned long)(m.Priority & 7) << 26 | m.PGN << 8 | source;
  if (((m.PGN >> 8) & 0xff) < 240) id |= (unsigned long)m.Destination << 8;
  if (m.DataLen <= 8 && !node.isFastPacket(m.PGN)) {
    receive(node, id, std::vector<unsigned char>(m.Data, m.Data + m.DataLen));
    return;
  }
  std::vector<unsigned char> first = {0x00, uint8_t(m.DataLen)};
  for (int i = 0; i < 6; i++) first.push_back(i < m.DataLen ? m.Data[i] : 0xff);
  receive(node, id, first);
  for (int frame = 1; 6 + (frame - 1) * 7 < m.DataLen; frame++) {
    std::vector<unsigned char> data = {uint8_t(frame)};
    for (int i = 6 + (frame - 1) * 7; i < 6 + frame * 7; i++) data.push_back(i < m.DataLen ? m.Data[i] : 0xff);
    receive(node, id, data);
  }
}

// Another device's NAME: unique number `unique`, manufacturer 2046.
uint64_t otherName(uint32_t unique) { return 0xc0328200ffc00000ULL | unique; }

// Sends wind data from a source every 100 ms until t, as a device on the
// bus would. The device list makes its requests while handling such messages.
void chatter(TestNode &node, unsigned char source, uint32_t t) {
  while (now - origin < t) {
    until(node, now - origin + 100 > t ? t : now - origin + 100);
    tN2kMsg m;
    SetN2kPGN130306(m, 1, 5, 1, N2kWind_True_North);
    inject(node, m, source);
  }
}

// Prints the device list's state, as the last events of a case.
void dumpDevices(tN2kDeviceList &list) {
  char line[256];
  snprintf(line, sizeof line, "devices count=%u updated=%d", list.Count(), list.ReadResetIsListUpdated());
  events.push_back(line);
  for (int source = 0; source < N2kMaxBusDevices; source++) {
    const tNMEA2000::tDevice *d = list.FindDeviceBySource(source);
    if (d == nullptr) continue;
    auto text = [](const char *s) { return std::string(s ? s : ""); };
    auto pgns = [](const unsigned long *list) {
      if (list == nullptr) return std::string("-");
      std::string s = "[";
      for (int i = 0; list[i] != 0; i++) s += (i ? ", " : "") + std::to_string(list[i]);
      return s + "]";
    };
    snprintf(line, sizeof line, "device source=%u name=0x%016llx", d->GetSource(),
             (unsigned long long)d->GetName());
    events.push_back(line);
    snprintf(line, sizeof line, "  product version=%u code=%u cert=%u load=%u", d->GetN2kVersion(),
             d->GetProductCode(), d->GetCertificationLevel(), d->GetLoadEquivalency());
    events.push_back(line + std::string(" model=") + text(d->GetModelID()) + " sw=" + text(d->GetSwCode()) +
                     " version=" + text(d->GetModelVersion()) + " serial=" + text(d->GetModelSerialCode()));
    events.push_back("  config manufacturer=" + text(d->GetManufacturerInformation()) +
                     " installation1=" + text(d->GetInstallationDescription1()) +
                     " installation2=" + text(d->GetInstallationDescription2()));
    events.push_back("  pgns transmit=" + pgns(d->GetTransmitPGNs()) + " receive=" + pgns(d->GetReceivePGNs()));
  }
}

// A stream over bytes, for upstream's Actisense reader and writer.
class ByteStream : public N2kStream {
 public:
  std::vector<uint8_t> input;
  size_t position = 0;
  std::vector<uint8_t> output;
  int read() override { return position < input.size() ? input[position++] : -1; }
  int peek() override { return position < input.size() ? input[position] : -1; }
  size_t write(const uint8_t *data, size_t size) override {
    output.insert(output.end(), data, data + size);
    return size;
  }
};

// Records the Actisense bytes upstream writes for a message.
void actisenseWrite(const tN2kMsg &m) {
  ByteStream stream;
  m.SendInActisenseFormat(&stream);
  events.push_back("actisense " + bytes(stream.output.data(), stream.output.size()));
}

// A message with the given fields and payload.
tN2kMsg makeMsg(unsigned long pgn, uint8_t priority, uint8_t source, uint8_t destination,
                uint32_t time, std::vector<unsigned char> data) {
  tN2kMsg m;
  m.SetPGN(pgn);
  m.Priority = priority;
  m.Source = source;
  m.Destination = destination;
  for (unsigned char b : data) m.AddByte(b);
  m.MsgTime = time;
  return m;
}

// Records the messages upstream's Actisense reader finds in some bytes.
void actisenseRead(std::vector<uint8_t> input) {
  ByteStream stream;
  stream.input = input;
  tActisenseReader reader;
  reader.SetReadStream(&stream);
  tN2kMsg m;
  while (stream.peek() != -1) {
    if (!reader.GetMessageFromStream(m)) continue;
    char line[96];
    snprintf(line, sizeof line, "message pgn=%lu priority=%u source=%u destination=%u time=%lu data=",
             m.PGN, m.Priority, m.Source, m.Destination, m.MsgTime == now ? 0xfffffffful : m.MsgTime);
    events.push_back(line + bytes(m.Data, m.DataLen));
  }
}

// The Actisense bytes of a typical message.
std::vector<uint8_t> actisenseBytes(const tN2kMsg &m) {
  ByteStream stream;
  m.SendInActisenseFormat(&stream);
  return stream.output;
}

std::vector<uint8_t> typicalActisense() {
  return actisenseBytes(makeMsg(127250, 2, 1, 255, 0x01020304, {1, 2, 3, 4, 5, 6, 7, 8}));
}

// Records the Seasmart sentence upstream writes for a message.
void seasmartWrite(const tN2kMsg &m, uint32_t timestamp) {
  char buffer[600];
  size_t count = N2kToSeasmart(m, timestamp, buffer, sizeof buffer);
  events.push_back("seasmart " + std::string(buffer, count));
}

// A Seasmart sentence with its checksum, flipped by `wrong` and in lower
// case if asked, then `tail`.
std::string sentence(const std::string &body, int wrong = 0, bool lower = false,
                     const char *tail = "") {
  int checksum = 0;
  for (char c : body) checksum ^= c;
  char text[8];
  snprintf(text, sizeof text, lower ? "*%02x" : "*%02X", checksum ^ wrong);
  return "$" + body + text + tail;
}

// Records what upstream reads from a Seasmart sentence.
void seasmartRead(const char *sentence) {
  tN2kMsg m;
  uint32_t timestamp = 0;
  if (!SeasmartToN2k(sentence, timestamp, m)) {
    events.push_back("rejected");
    return;
  }
  char line[96];
  snprintf(line, sizeof line, "message pgn=%lu source=%u time=%u data=", m.PGN, m.Source, timestamp);
  events.push_back(line + bytes(m.Data, m.DataLen));
}

// The node a case runs, for the ISO request handler.
TestNode *current = nullptr;

// Answers requests for 130306 with a one-byte message, and refuses others.
bool requestHandler(unsigned long pgn, unsigned char requester, int) {
  if (pgn != 130306) return false;
  tN2kMsg m;
  m.SetPGN(130306);
  m.Destination = requester;
  m.AddByte(requester);
  current->SendMsg(m);
  return true;
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
    // Heartbeats.
    NODE("heartbeat", start(n, tNMEA2000::N2km_NodeOnly); until(n, 70300)),
    NODE("heartbeat waits for the address claim", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 10150);
      claim(n, 23, ownName - 1);
      until(n, 10500);
    }),
    NODE("heartbeat sequence wraps after 252", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 600);
      // Polling once a second, 250 heartbeats take until 15 000 s.
      until(n, 15000000, 1000);
      events.clear();
      until(n, 15200000, 1000);
    }),
    NODE("heartbeat needs a full node", start(n, tNMEA2000::N2km_ListenAndSend); until(n, 10300)),

    // ISO requests from 0x42. The node is at 23 (0x17).
    NODE("ISO request for the address claim", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0xff, 60928);
      request(n, 0x17, 60928);
    }),
    NODE("ISO request during the address claim", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 300);
      request(n, 0x17, 60928);
      request(n, 0x17, 130306);
    }),
    NODE("ISO request for product information", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0x17, 126996);
    }),
    NODE("ISO request for configuration information", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0xff, 126998);
    }),
    NODE("ISO request for missing configuration information", {
      n.SetProgmemConfigurationInformation(0, 0, 0);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0x17, 126998);
    }),
    NODE("ISO request for the PGN lists", {
      static const unsigned long transmit[] = {127250, 129025, 0};
      static const unsigned long receive[] = {130306, 0};
      n.ExtendTransmitMessages(transmit);
      n.ExtendReceiveMessages(receive);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0x17, 126464);
    }),
    NODE("ISO request for an unknown PGN", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0x17, 130310);
      request(n, 0xff, 130310);
      request(n, 0x30, 130310);
    }),
    NODE("ISO request of the wrong length", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      // A request shorter than 3 bytes asks for PGN 0; upstream ignores the
      // parse failure.
      request(n, 0x17, 130310, 2);
      request(n, 0x17, 130310, 8);
    }),
    NODE("ISO request answered by the application", {
      current = &n;
      n.SetISORqstHandler(requestHandler);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0x17, 130306);
      request(n, 0x17, 130310);
      request(n, 0xff, 130306);
      request(n, 0xff, 130310);
    }),
    NODE("ISO request ignored when broadcast", {
      current = &n;
      n.SetISORqstHandler(requestHandler);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      request(n, 0xff, 127500);
      request(n, 0x17, 127500);
    }),
    NODE("ISO request needs a full node", {
      start(n, tNMEA2000::N2km_ListenAndSend);
      until(n, 500);
      request(n, 0x17, 60928);
      request(n, 0x17, 130310);
    }),
    // Commanded address.
    NODE("commanded address", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      command(n, ownName, 0x30);
      send(n, 129025, 8, 2);
      until(n, 750);
      send(n, 129025, 8, 2);
    }),
    NODE("commanded address for another NAME", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      command(n, ownName - 1, 0x30);
    }),
    NODE("commanded address that doesn't change it", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      command(n, ownName, 23);
    }),
    NODE("commanded address out of range", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      command(n, ownName, 252);
      command(n, ownName, 251);
    }),
    NODE("commanded address of the wrong length", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      command(n, ownName, 0x30, 1);
    }),
    NODE("commanded address as a fast packet", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      receive(n, 0x18fed842, fp(0x00, {9, 0x01, 0x00, 0xc0, 0xff, 0x00, 0x82}));
      receive(n, 0x18fed842, fp(0x01, {0x32, 0xc0, 0x30}));
    }),
    NODE("commanded address while claiming", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 300);
      command(n, ownName, 0x30);
    }),
    NODE("commanded address needs a full node", {
      start(n, tNMEA2000::N2km_ListenAndSend);
      until(n, 500);
      command(n, ownName, 0x30);
    }),
    // Group functions from 0x42. The node is at 23 (0x17); 130310 is a PGN it
    // doesn't transmit unless a case says so.
#define GF_NODE(name, ...) NODE("group function " name, { \
      start(n, tNMEA2000::N2km_NodeOnly); \
      until(n, 500); \
      __VA_ARGS__; \
    })
    GF_NODE("request for an unknown PGN", groupFunction(n, 0x17, gfRequest(130310, 0xffffffff, 0xffff, 0))),
    GF_NODE("request with parameter pairs", groupFunction(n, 0x17, gfRequest(130310, 0xffffffff, 0xffff, 3, {1, 2, 3}))),
    GF_NODE("request broadcast", groupFunction(n, 0xff, gfRequest(130310, 0xffffffff, 0xffff, 0))),
    NODE("group function request for a transmitted PGN", {
      static const unsigned long transmit[] = {130310, 0};
      n.ExtendTransmitMessages(transmit);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      groupFunction(n, 0x17, gfRequest(130310, 0xffffffff, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(130310, 0, 0, 0));
      groupFunction(n, 0x17, gfRequest(130310, 0xfffffffe, 0, 0));
      groupFunction(n, 0x17, gfRequest(130310, 1000, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(130310, 0xffffffff, 5, 0));
    }),
    GF_NODE("command for an unknown PGN", {
      groupFunction(n, 0x17, gfCommand(130310, 8, 0));
      groupFunction(n, 0x17, gfCommand(130310, 3, 2, {1, 2, 3, 4}));
      groupFunction(n, 0xff, gfCommand(130310, 8, 0));
    }),
    NODE("group function command for a transmitted PGN", {
      static const unsigned long transmit[] = {130310, 0};
      n.ExtendTransmitMessages(transmit);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      groupFunction(n, 0x17, gfCommand(130310, 8, 0));
      groupFunction(n, 0x17, gfCommand(130310, 9, 0));
      groupFunction(n, 0x17, gfCommand(130310, 0x0f, 0));
      groupFunction(n, 0x17, gfCommand(130310, 7, 0));
    }),
    GF_NODE("read and write", {
      groupFunction(n, 0x17, gf(3, 130310, {0, 0, 2}));
      groupFunction(n, 0x17, gf(5, 126996, {0, 1, 1}));
      groupFunction(n, 0x17, gf(3, 130816, {0x6d, 0x18, 0, 0, 3}));
      groupFunction(n, 0xff, gf(5, 130310, {0, 0, 2}));
    }),
    GF_NODE("acknowledgements and replies", {
      groupFunction(n, 0x17, gf(2, 130310, {0x01, 0}));
      groupFunction(n, 0x17, gf(4, 130310, {0, 0, 0}));
      groupFunction(n, 0x17, gf(6, 130310, {0, 0, 0}));
      groupFunction(n, 0x17, gf(7, 130310, {0, 0, 0}));
    }),
    GF_NODE("for another node", groupFunction(n, 0x30, gfRequest(130310, 0xffffffff, 0xffff, 0))),
    GF_NODE("request for the address claim", {
      groupFunction(n, 0x17, gfRequest(60928, 0xffffffff, 0xffff, 0));
      until(n, 520);
      groupFunction(n, 0x17, gfRequest(60928, 1000, 0xffff, 0));
    }),
    GF_NODE("request for the address claim with matching fields", {
      groupFunction(n, 0x17, gfRequest(60928, 0xffffffff, 0xffff, 10,
                                       {1, 0x01, 0x00, 0xe0, 2, 0xfe, 0xff, 3, 0, 4, 0, 5, 130,
                                        6, 0x55, 7, 25, 8, 0, 9, 4, 10, 0x55}));
      until(n, 520);
    }),
    GF_NODE("request for the address claim with other fields", {
      groupFunction(n, 0x17, gfRequest(60928, 0xffffffff, 0xffff, 3, {2, 100, 0, 5, 131, 8, 0}));
      groupFunction(n, 0x17, gfRequest(60928, 0xffffffff, 0xffff, 3, {11, 1, 2, 4, 0}));
      groupFunction(n, 0xff, gfRequest(60928, 0xffffffff, 0xffff, 2, {2, 100, 0, 5, 130}));
      groupFunction(n, 0xff, gfRequest(60928, 0xffffffff, 0xffff, 1, {5, 130}));
      until(n, 520);
    }),
    GF_NODE("command for the address claim", {
      groupFunction(n, 0x17, gfCommand(60928, 8, 3, {3, 5, 4, 0x1f, 8, 7}));
      until(n, 520);
      groupFunction(n, 0x17, gfCommand(60928, 2, 2, {9, 3, 1}));
      until(n, 540);
      groupFunction(n, 0xff, gfCommand(60928, 8, 1, {3, 2}));
      until(n, 560);
    }),
    GF_NODE("request for the PGN lists", {
      groupFunction(n, 0x17, gfRequest(126464, 0xffffffff, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(126464, 0xffffffff, 0xffff, 1, {1, 1}));
      groupFunction(n, 0x17, gfRequest(126464, 0xffffffff, 0xffff, 1, {1, 2}));
      groupFunction(n, 0xff, gfRequest(126464, 0xffffffff, 0xffff, 1, {1, 0}));
    }),
    GF_NODE("request for the PGN lists by transport protocol", {
      groupFunction(n, 0xff, gfRequest(126464, 0xffffffff, 0xffff, 0), true);
      until(n, 700);
    }),
    GF_NODE("request for product information", {
      groupFunction(n, 0x17, gfRequest(126996, 0xffffffff, 0xffff, 2, {1, 0x35, 0x08, 2, 0x9a, 0x02}));
      groupFunction(n, 0x17, gfRequest(126996, 0xffffffff, 0xffff, 2, {7, 1, 8, 1}));
      groupFunction(n, 0xff, gfRequest(126996, 0xffffffff, 0xffff, 1, {8, 2}));
    }),
    GF_NODE("request for product information by model ID", {
      std::vector<unsigned char> model = {3};
      const char *id = "Arduino N2k->PC";
      for (int i = 0; i < 32; i++) model.push_back(i < (int)strlen(id) ? id[i] : 0xff);
      groupFunction(n, 0x17, gfRequest(126996, 0xffffffff, 0xffff, 1, model), true);
      until(n, 600);
    }),
    GF_NODE("request for product information by software version", {
      // Upstream compares the software version with the model ID.
      std::vector<unsigned char> version = {4};
      const char *id = "1.0.0.0";
      for (int i = 0; i < 32; i++) version.push_back(i < (int)strlen(id) ? id[i] : 0xff);
      groupFunction(n, 0x17, gfRequest(126996, 0xffffffff, 0xffff, 1, version), true);
      until(n, 600);
    }),
    GF_NODE("request for configuration information", {
      groupFunction(n, 0x17, gfRequest(126998, 0xffffffff, 0xffff, 1, std::vector<unsigned char>{1} + varStr("")));
      groupFunction(n, 0x17, gfRequest(126998, 0xffffffff, 0xffff, 1, std::vector<unsigned char>{2} + varStr("x")));
      groupFunction(n, 0x17, gfRequest(126998, 0xffffffff, 0xffff, 2, std::vector<unsigned char>{4, 1} + varStr("")));
    }),
    GF_NODE("command for configuration information", {
      groupFunction(n, 0x17, gfCommand(126998, 8, 3, std::vector<unsigned char>{1} + varStr("Bow") + std::vector<unsigned char>{2} + varStr("Port side") + std::vector<unsigned char>{3}));
      groupFunction(n, 0x17, gfRequest(126998, 0xffffffff, 0xffff, 1, std::vector<unsigned char>{2} + varStr("Port side")));
      groupFunction(n, 0x17, gfCommand(126998, 5, 1, std::vector<unsigned char>{1} + varStr("")));
      request(n, 0x17, 126998);
    }),
    NODE("group function command for missing configuration information", {
      n.SetProgmemConfigurationInformation(0, 0, 0);
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 500);
      groupFunction(n, 0x17, gfCommand(126998, 8, 1, std::vector<unsigned char>{2} + varStr("Aft")));
      request(n, 0x17, 126998);
    }),
    GF_NODE("request for the heartbeat interval", {
      groupFunction(n, 0x17, gfRequest(126993, 2000, 0xffff, 0));
      until(n, 12300);
    }),
    GF_NODE("request for the heartbeat interval and offset", {
      groupFunction(n, 0xff, gfRequest(126993, 5000, 100, 0));
      until(n, 6300);
    }),
    GF_NODE("request for the default heartbeat interval", {
      groupFunction(n, 0x17, gfRequest(126993, 2000, 0, 0));
      groupFunction(n, 0x17, gfRequest(126993, 0xfffffffe, 0, 0));
      until(n, 10300);
    }),
    GF_NODE("request for an unsupported heartbeat interval", {
      groupFunction(n, 0x17, gfRequest(126993, 999, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(126993, 60001, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(126993, 0, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(126993, 1000, 6001, 0));
      groupFunction(n, 0xff, gfRequest(126993, 999, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(126993, 0xffffffff, 0xffff, 0));
      groupFunction(n, 0x17, gfRequest(126993, 1000, 0xffff, 1, {1, 2}));
      groupFunction(n, 0x17, gfCommand(126993, 8, 0));
    }),
    GF_NODE("request for the address claim to the millisecond", {
      groupFunction(n, 0x17, gfRequest(60928, 0xffffffff, 0xffff, 0));
      until(n, 505, 1);
    }),
    GF_NODE("command for the address claim to the millisecond", {
      groupFunction(n, 0x17, gfCommand(60928, 8, 1, {8, 0x0d}));
      until(n, 505, 1);
    }),
    NODE("group function request for the heartbeat offset at its time", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 1200);
      // The node opened at 200, so an offset of 1 s falls due now.
      groupFunction(n, 0xff, gfRequest(126993, 5000, 100, 0));
      until(n, 6300);
    }),
    GF_NODE("command for a long installation description", {
      groupFunction(n, 0x17, gfCommand(126998, 8, 1, std::vector<unsigned char>{1} + varStr("0123456789012345678901234567890123456789012345678901234567890123456789XYZ")));
      groupFunction(n, 0x17, gfRequest(126998, 0xffffffff, 0xffff, 1, std::vector<unsigned char>{1} + varStr("0123456789012345678901234567890123456789012345678901234567890123456789")));
    }),
    NODE("group function during the address claim", {
      start(n, tNMEA2000::N2km_NodeOnly);
      until(n, 300);
      groupFunction(n, 0x17, gfRequest(130310, 0xffffffff, 0xffff, 0));
      groupFunction(n, 0x17, gfCommand(60928, 8, 1, {3, 5}));
      until(n, 320);
    }),
    NODE("group function needs a full node", {
      start(n, tNMEA2000::N2km_ListenAndSend);
      until(n, 500);
      groupFunction(n, 0x17, gfRequest(130310, 0xffffffff, 0xffff, 0));
    }),
    // Device list. Device 0x42 answers nothing unless a case says so.
#define DL_NODE(name, mode, ...) NODE("device list " name, { \
      tN2kDeviceList list(&n); \
      start(n, mode); \
      until(n, 500); \
      __VA_ARGS__; \
      dumpDevices(list); \
    })
    DL_NODE("discovers a device from its address claim", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0x42, otherName(7));
      chatter(n, 0x42, 1600);
      tN2kMsg product;
      SetN2kPGN126996(product, 2100, 1234, "Wind sensor", "2.0", "B", "SN7", 1, 2);
      inject(n, product, 0x42);
      chatter(n, 0x42, 2700);
      tN2kMsg config;
      SetN2kPGN126998(config, "Maker", "Masthead", "");
      inject(n, config, 0x42);
      chatter(n, 0x42, 3800);
      static const unsigned long transmit[] = {130306, 60928, 0};
      static const unsigned long receive[] = {59904, 0};
      tN2kMsg tx, rx;
      SetN2kPGN126464(tx, 0x17, N2kpgnl_transmit, transmit);
      SetN2kPGN126464(rx, 0x17, N2kpgnl_receive, receive);
      inject(n, tx, 0x42);
      inject(n, rx, 0x42);
      chatter(n, 0x42, 4000);
    }),
    DL_NODE("asks a device it hears from for its NAME", tNMEA2000::N2km_NodeOnly, {
      chatter(n, 0x42, 800);
      claim(n, 0x42, otherName(7));
      chatter(n, 0x42, 1000);
    }),
    DL_NODE("gives up on a device that doesn't answer", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0x42, otherName(7));
      chatter(n, 0x42, 14000);
    }),
    DL_NODE("follows a device to a new address", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0x42, otherName(7));
      claim(n, 0x43, otherName(7));
    }),
    DL_NODE("moves a device whose address is taken", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0x42, otherName(7));
      claim(n, 0x42, otherName(8));
    }),
    DL_NODE("can't ask while the node claims its address", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0x17, ownName - 1);
      chatter(n, 0x42, 800);
    }),
    DL_NODE("stops asking a silent device for its NAME", tNMEA2000::N2km_NodeOnly, {
      // A device first heard by an ordinary message has never had a message
      // time, so a minute after the node starts, upstream clears its count of
      // NAME requests on the first one. Wait that minute, as on a real bus.
      until(n, 61000);
      chatter(n, 0x42, 63500);
    }),
    DL_NODE("asks for configuration information over a second after adding", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0x42, otherName(7));
      tN2kMsg product;
      SetN2kPGN126996(product, 2100, 1234, "Wind sensor", "2.0", "B", "SN7", 1, 2);
      until(n, 600);
      inject(n, product, 0x42);
      chatter(n, 0x42, 1700);
    }),
    DL_NODE("keeps a device at address 253", tNMEA2000::N2km_NodeOnly, {
      claim(n, 0xfd, otherName(9));
      claim(n, 0xfe, otherName(10));
    }),
    DL_NODE("in listen only mode", tNMEA2000::N2km_ListenOnly, {
      chatter(n, 0x42, 800);
      claim(n, 0x43, otherName(8));
      chatter(n, 0x43, 2000);
    }),
    // Actisense gateway format. A decoded time of 4294967295 means the
    // reader used the current time.
    {"Actisense write typical", [](TestNode &) {
       actisenseWrite(makeMsg(127250, 2, 1, 255, 0x01020304, {1, 2, 3, 4, 5, 6, 7, 8}));
     }},
    {"Actisense write escapes", [](TestNode &) {
       actisenseWrite(makeMsg(0x1f010, 6, 0x10, 0x10, 0x10101010, {0x10, 0x02, 0x10, 0x03}));
     }},
    {"Actisense write checksum to escape", [](TestNode &) {
       for (int b = 0; b < 256; b++) {
         tN2kMsg m = makeMsg(130306, 2, 7, 255, 1234, {1, 2, uint8_t(b)});
         std::vector<uint8_t> out = actisenseBytes(m);
         if (out[out.size() - 3] == 0x10 && out[out.size() - 4] == 0x10) {
           actisenseWrite(m);
           break;
         }
       }
     }},
    {"Actisense write not valid", [](TestNode &) {
       actisenseWrite(makeMsg(0, 2, 1, 255, 0, {1}));
       actisenseWrite(makeMsg(127250, 2, 1, 255, 0, {}));
     }},
    {"Actisense write long", [](TestNode &) {
       std::vector<unsigned char> data;
       for (int i = 0; i < 223; i++) data.push_back(uint8_t(0x20 + i % 0x50));
       actisenseWrite(makeMsg(126996, 6, 33, 255, 0xfffffffe, data));
     }},
    {"Actisense read typical", [](TestNode &) { actisenseRead(typicalActisense()); }},
    {"Actisense read escapes", [](TestNode &) {
       actisenseRead(actisenseBytes(makeMsg(0x1f010, 6, 0x10, 0x10, 0x10101010, {0x10, 0x02, 0x10, 0x03})));
     }},
    {"Actisense read two messages and noise", [](TestNode &) {
       std::vector<uint8_t> input = {0x41, 0x10, 0x10, 0x03, 0x02, 0x10};
       for (uint8_t b : typicalActisense()) input.push_back(b);
       input.push_back(0x55);
       for (uint8_t b : actisenseBytes(makeMsg(130306, 2, 7, 255, 1234, {1, 2, 3}))) input.push_back(b);
       actisenseRead(input);
     }},
    {"Actisense read request", [](TestNode &) {
       // A request to send: type, length, priority, PGN, destination, data length, data, checksum.
       std::vector<uint8_t> body = {0x94, 8, 3, 0x12, 0xf1, 0x01, 0x17, 2, 0xaa, 0xbb};
       int sum = 0;
       for (uint8_t b : body) sum += b;
       std::vector<uint8_t> input = {0x10, 0x02};
       input.insert(input.end(), body.begin(), body.end());
       input.push_back(uint8_t(256 - sum % 256));
       input.push_back(0x10);
       input.push_back(0x03);
       actisenseRead(input);
     }},
    {"Actisense read bad checksum", [](TestNode &) {
       std::vector<uint8_t> input = typicalActisense();
       input[input.size() - 3] ^= 1;
       actisenseRead(input);
     }},
    {"Actisense read wrong length", [](TestNode &) {
       std::vector<uint8_t> input = typicalActisense();
       input[3] += 1;
       actisenseRead(input);
       input = typicalActisense();
       input[15] += 1;  // The data length byte.
       actisenseRead(input);
     }},
    {"Actisense read unknown type", [](TestNode &) {
       std::vector<uint8_t> input = typicalActisense();
       input[2] = 0xa0;
       actisenseRead(input);
     }},
    {"Actisense read restarted", [](TestNode &) {
       std::vector<uint8_t> input = {0x10, 0x02, 0x93, 0x05, 0x01, 0x10, 0x02};
       std::vector<uint8_t> rest = typicalActisense();
       input.insert(input.end(), rest.begin() + 2, rest.end());
       actisenseRead(input);
     }},
    {"Actisense read broken escape", [](TestNode &) {
       std::vector<uint8_t> input = {0x10, 0x02, 0x93, 0x05, 0x10, 0x41};
       std::vector<uint8_t> rest = typicalActisense();
       input.insert(input.end(), rest.begin(), rest.end());
       actisenseRead(input);
     }},
    {"Actisense read too long", [](TestNode &) {
       std::vector<uint8_t> input = {0x10, 0x02, 0x93};
       for (int i = 0; i < 300; i++) input.push_back(0x20);
       std::vector<uint8_t> rest = typicalActisense();
       input.insert(input.end(), rest.begin(), rest.end());
       actisenseRead(input);
     }},
    {"Actisense read empty payload", [](TestNode &) {
       std::vector<uint8_t> body = {0x93, 11, 2, 0x12, 0xf1, 0x01, 0xff, 0x01, 4, 3, 2, 1, 0};
       int sum = 0;
       for (uint8_t b : body) sum += b;
       std::vector<uint8_t> input = {0x10, 0x02};
       input.insert(input.end(), body.begin(), body.end());
       input.push_back(uint8_t(256 - sum % 256));
       input.push_back(0x10);
       input.push_back(0x03);
       actisenseRead(input);
     }},
    {"Actisense read full buffer then escaped escape", [](TestNode &) {
       // A full 300-byte body, then DLE DLE STX: the escaped DLE doesn't
       // fit, which drops the body, so the STX that follows starts nothing.
       std::vector<uint8_t> input = {0x10, 0x02, 0x93};
       for (int i = 0; i < 299; i++) input.push_back(0x20);
       input.push_back(0x10);
       input.push_back(0x10);
       std::vector<uint8_t> rest = typicalActisense();
       input.insert(input.end(), rest.begin() + 1, rest.end());
       actisenseRead(input);
     }},
    {"Actisense read data longer than a message", [](TestNode &) {
       // 224 data bytes.
       std::vector<uint8_t> body = {0x93, 235, 2, 0x12, 0xf1, 0x01, 0xff, 0x01, 0, 0, 0, 0, 224};
       for (int i = 0; i < 224; i++) body.push_back(0x20);
       int sum = 0;
       for (uint8_t b : body) sum += b;
       std::vector<uint8_t> input = {0x10, 0x02};
       input.insert(input.end(), body.begin(), body.end());
       input.push_back(uint8_t(256 - sum % 256));
       input.push_back(0x10);
       input.push_back(0x03);
       actisenseRead(input);
     }},
    // Seasmart ($PCDIN) gateway format.
    {"Seasmart write", [](TestNode &) {
       seasmartWrite(makeMsg(127250, 2, 1, 255, 0, {1, 2, 3, 0xab, 0xcd, 0xef, 0x10, 0xff}), 0x01020304);
       seasmartWrite(makeMsg(0x1ffff, 7, 255, 255, 0, {0}), 0xffffffff);
       seasmartWrite(makeMsg(59904, 6, 0, 0x42, 0, {}), 0);
     }},
    {"Seasmart read", [](TestNode &) {
       seasmartRead(sentence("PCDIN,01F112,01020304,01,010203ABCDEF10FF").c_str());
       seasmartRead(sentence("pcdin,01f112,01020304,01,010203abcdef10ff", 0, true).c_str());
       seasmartRead(sentence("PCDIN,01f112,01020304,01,010203abcdef10ff", 0, true).c_str());
       seasmartRead(sentence("PCDIN,01F112,01020304,01,010203ABCDEF10FF", 0, false, "\r\n").c_str());
       seasmartRead(sentence("PCDIN,01F112,01020304,01,").c_str());
     }},
    {"Seasmart read rejects", [](TestNode &) {
       seasmartRead(sentence("PCDIN,01F112,01020304,01,010203ABCDEF10FF", 1).c_str());
       seasmartRead(sentence("PCDIN,01F112,01020304,01,010203ABCDEF10F").c_str());
       seasmartRead(sentence("PCDIN,01F112;01020304,01,01").c_str());
       seasmartRead(sentence("PCDIN,01F112,01020304;01,01").c_str());
       seasmartRead(sentence("PCDIN,01F112,01020304,01;01").c_str());
       seasmartRead("$PCDIN,01F112,01020304,01,01");
       seasmartRead(sentence("PCDIN,01F112,01020304,01,0G").c_str());
       seasmartRead(sentence("PCDIN,01G112,01020304,01,01").c_str());
       seasmartRead(sentence("GPGGA,01F112,01020304,01,01").c_str());
       seasmartRead("$PCDIN,01F112,0102");
       seasmartRead("$PCDIN,01F112,01020304,01,01*");
       seasmartRead("$PCDIN,01F112,01020304,01,01*0");
     }},
    {"Seasmart read longest", [](TestNode &) {
       std::string data;
       for (int i = 0; i < 223; i++) data += "A5";
       std::string body = "PCDIN,01F014,00000000,21," + data;
       int checksum = 0;
       for (char c : body) checksum ^= c;
       char tail[8];
       snprintf(tail, sizeof tail, "*%02X", checksum);
       seasmartRead(("$" + body + tail).c_str());
       body += "A5";
       checksum = 0;
       for (char c : body) checksum ^= c;
       snprintf(tail, sizeof tail, "*%02X", checksum);
       seasmartRead(("$" + body + tail).c_str());
     }},
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
