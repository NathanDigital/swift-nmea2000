// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Synchronization
import Testing

/// A clock that only moves when a test advances it.
final class ManualClock: Clock {
  struct Instant: InstantProtocol {
    var offset: Duration

    func advanced(by duration: Duration) -> Instant { Instant(offset: offset + duration) }
    func duration(to other: Instant) -> Duration { other.offset - offset }
    static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
  }

  private struct Sleeper {
    var id: Int
    var deadline: Instant
    var continuation: CheckedContinuation<Void, any Error>
  }

  private struct State {
    var now = Instant(offset: .zero)
    var sleepers: [Sleeper] = []
    var nextID = 0
  }

  private let state = Mutex(State())

  var now: Instant { state.withLock { $0.now } }
  var minimumResolution: Duration { .zero }

  /// How many tasks are sleeping on the clock.
  var sleeperCount: Int { state.withLock { $0.sleepers.count } }

  func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    let id = state.withLock { state in
      defer { state.nextID += 1 }
      return state.nextID
    }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let result: Result<Void, any Error>? = state.withLock { state in
          if Task.isCancelled { return .failure(CancellationError()) }
          if deadline <= state.now { return .success(()) }
          state.sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
          return nil
        }
        if let result { continuation.resume(with: result) }
      }
    } onCancel: {
      let sleeper = state.withLock { state in
        state.sleepers.firstIndex { $0.id == id }.map { state.sleepers.remove(at: $0) }
      }
      sleeper?.continuation.resume(throwing: CancellationError())
    }
  }

  /// Moves the clock to a time, waking the tasks whose deadlines it reaches.
  func advance(to milliseconds: Int) {
    let woken = state.withLock { state in
      state.now = Instant(offset: .milliseconds(milliseconds))
      let now = state.now
      let woken = state.sleepers.filter { $0.deadline <= now }
      state.sleepers.removeAll { $0.deadline <= now }
      return woken
    }
    for sleeper in woken { sleeper.continuation.resume() }
  }

  /// Waits until a number of tasks are sleeping on the clock.
  ///
  /// - Throws: `CancellationError` if the test times out first.
  func waitForSleepers(_ count: Int = 1) async throws {
    while sleeperCount < count {
      try Task.checkCancellation()
      await Task.yield()
    }
  }
}

/// A transport whose received frames a test supplies, and which records the
/// frames it sends.
final class FakeTransport: CANTransport {
  let received: AsyncStream<CANFrame>
  let receive: AsyncStream<CANFrame>.Continuation
  let sent: AsyncStream<CANFrame>
  private let sentContinuation: AsyncStream<CANFrame>.Continuation
  private let failures: Mutex<Int>
  private let opens = Mutex(0)

  struct OpenFailed: Error {}

  init(failingOpens: Int = 0) {
    (received, receive) = AsyncStream.makeStream(of: CANFrame.self)
    (sent, sentContinuation) = AsyncStream.makeStream(of: CANFrame.self)
    failures = Mutex(failingOpens)
  }

  /// How many times the node tried to open the transport.
  var openCount: Int { opens.withLock { $0 } }

  func open() async throws -> AsyncStream<CANFrame> {
    opens.withLock { $0 += 1 }
    let fails = failures.withLock { failures in
      defer { failures = max(failures - 1, 0) }
      return failures > 0
    }
    if fails { throw OpenFailed() }
    return received
  }

  func send(_ frame: CANFrame) async throws {
    // Give other tasks a chance to interleave their frames.
    await Task.yield()
    sentContinuation.yield(frame)
  }
}

private let claim: CANFrame = CANFrame(
  id: 0x18ee_ff17, data: [0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0])

// A broken node can leave a test waiting for a frame that never comes, so
// stop any test that runs for a minute.
@Suite("Node", .timeLimit(.minutes(1)))
struct NodeTests {
  @Test func claimsSendsAndReceives() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let messages = await node.messages()
    let run = Task { try await node.run() }
    var sent = transport.sent.makeAsyncIterator()

    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(await sent.next() == claim)

    clock.advance(to: 449)
    await #expect(throws: NodeError.claimingAddress) {
      try await node.send(PositionRapidUpdate(latitude: 1, longitude: 2))
    }
    clock.advance(to: 450)
    try await node.send(PositionRapidUpdate(latitude: 1, longitude: 2))
    #expect(await sent.next()?.id == 0x09f8_0117)

    transport.receive.yield(CANFrame(id: 0x09f8_0142, data: [1, 2, 3, 4, 5, 6, 7, 8]))
    var iterator = messages.makeAsyncIterator()
    let message = try #require(await iterator.next())
    #expect(message.pgn == 129025)
    #expect(message.source == 0x42)
    #expect(message.data == [1, 2, 3, 4, 5, 6, 7, 8])
    #expect(message.timestamp == 450)

    transport.receive.finish()
    try await run.value
    #expect(await iterator.next() == nil)
  }

  @Test func defendsItsAddress() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    var sent = transport.sent.makeAsyncIterator()
    try await clock.waitForSleepers()
    clock.advance(to: 500)
    #expect(await sent.next() == claim)

    // A lower NAME takes address 23, so the node claims 24.
    transport.receive.yield(
      CANFrame(id: 0x18ee_ff17, data: [0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]))
    #expect(await sent.next() == CANFrame(id: 0x18ee_ff18, data: claim.data))
    #expect(await node.address == 24)

    run.cancel()
    transport.receive.finish()
    try await run.value
  }

  @Test func retriesOpeningEverySecond() async throws {
    let clock = ManualClock()
    let transport = FakeTransport(failingOpens: 2)
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    var sent = transport.sent.makeAsyncIterator()

    try await clock.waitForSleepers()
    #expect(transport.openCount == 1)
    clock.advance(to: 1000)
    try await clock.waitForSleepers()
    #expect(transport.openCount == 2)
    clock.advance(to: 2000)
    try await clock.waitForSleepers()
    #expect(transport.openCount == 3)
    clock.advance(to: 2200)
    #expect(await sent.next() == claim)

    transport.receive.finish()
    try await run.value
  }

  @Test func stopsOpeningWhenCancelled() async throws {
    let clock = ManualClock()
    let transport = FakeTransport(failingOpens: .max)
    let node = Node(transport: transport, clock: clock)
    let run = Task { try await node.run() }
    try await clock.waitForSleepers()
    run.cancel()
    await #expect(throws: CancellationError.self) { try await run.value }
  }

  @Test func refusesToSendBeforeRunning() async {
    let node = Node(transport: FakeTransport(), mode: .node, clock: ManualClock())
    await #expect(throws: NodeError.notOpen) {
      try await node.send(Message(pgn: 129025, data: [1, 2, 3, 4, 5, 6, 7, 8]))
    }
  }

  @Test func keepsEachMessagesFramesTogether() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .listenAndSend, address: 23, clock: clock)
    let run = Task { try await node.run() }
    try await clock.waitForSleepers()
    clock.advance(to: 200)

    // Two fast packets of the same PGN, sent at once.
    let first = Message(pgn: 129029, data: Array(repeating: 1, count: 43))
    let second = Message(pgn: 129029, data: Array(repeating: 2, count: 43))
    async let sendFirst: Void = node.send(first)
    async let sendSecond: Void = node.send(second)
    _ = try await (sendFirst, sendSecond)

    var frames: [CANFrame] = []
    for await frame in transport.sent {
      frames.append(frame)
      if frames.count == 14 { break }
    }
    // Each fast packet's seven frames are sent together, in order.
    let sequences = frames.map { $0.data[0] >> 5 }
    #expect(
      sequences == Array(repeating: sequences[0], count: 7)
        + Array(repeating: sequences[7], count: 7))
    #expect(frames.map { $0.data[0] & 0x1f } == Array(0..<7) + Array(0..<7))

    transport.receive.finish()
    try await run.value
  }

  @Test func sendsTransportProtocolPacketsOnTime() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    var sent = transport.sent.makeAsyncIterator()
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(await sent.next() == claim)
    clock.advance(to: 450)

    try await node.send(
      Message(pgn: 126464, data: Array(0..<10), isTransportProtocol: true))
    #expect(await sent.next()?.id == 0x18ec_ff17)
    // The node wakes itself for each data packet.
    try await clock.waitForSleepers()
    clock.advance(to: 500)
    #expect(await sent.next() == CANFrame(id: 0x18eb_ff17, data: [1, 0, 1, 2, 3, 4, 5, 6]))
    try await clock.waitForSleepers()
    clock.advance(to: 550)
    #expect(
      await sent.next() == CANFrame(id: 0x18eb_ff17, data: [2, 7, 8, 9, 0xff, 0xff, 0xff, 0xff]))

    transport.receive.finish()
    try await run.value
  }

  @Test func deliversEveryMessageToEverySubscriber() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, clock: clock)
    let first = await node.messages()
    let second = await node.messages()
    let run = Task { try await node.run() }
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    transport.receive.yield(CANFrame(id: 0x09f8_0142, data: [1, 2, 3, 4, 5, 6, 7, 8]))
    transport.receive.finish()
    try await run.value
    #expect(await first.map(\.pgn).reduce(into: []) { $0.append($1) } == [129025])
    #expect(await second.map(\.pgn).reduce(into: []) { $0.append($1) } == [129025])
  }
}
