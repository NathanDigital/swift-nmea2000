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
  func waitForSleepers(_ count: Int = 1) async throws {
    try await eventually { sleeperCount >= count ? () : nil }
  }
}

/// A test waited for something that didn't happen.
struct TimedOut: Error {}

/// Polls `check` until it returns a value, giving up after a few seconds.
///
/// A broken node can leave a test waiting for a frame that never comes. This
/// fails the test quickly instead, which keeps mutation testing fast.
func eventually<T>(_ check: () -> T?) async throws -> T {
  let deadline = ContinuousClock.now + .seconds(5)
  while true {
    if let value = check() { return value }
    guard ContinuousClock.now < deadline else { throw TimedOut() }
    try await Task.sleep(for: .milliseconds(1))
  }
}

/// Collects the elements of a sequence as they arrive, so a test can wait for
/// them with a deadline.
final class Recorder<Element: Sendable>: Sendable {
  private struct State {
    var elements: [Element] = []
    var isFinished = false
    var nextIndex = 0
  }

  private let state = Mutex(State())

  init<S: AsyncSequence & Sendable>(_ sequence: S) where S.Element == Element {
    Task {
      do {
        for try await element in sequence { self.append(element) }
      } catch {}
      self.markFinished()
    }
  }

  private func append(_ element: Element) {
    state.withLock { $0.elements.append(element) }
  }

  private func markFinished() {
    state.withLock { $0.isFinished = true }
  }

  /// Waits for the next element, or `nil` once the sequence has finished.
  func next() async throws -> Element? {
    try await eventually {
      state.withLock { state -> Element?? in
        if state.nextIndex < state.elements.count {
          defer { state.nextIndex += 1 }
          return .some(state.elements[state.nextIndex])
        }
        return state.isFinished ? .some(nil) : nil
      }
    }
  }

  /// Waits for the sequence to finish, and returns every element.
  func all() async throws -> [Element] {
    try await eventually { state.withLock { $0.isFinished ? $0.elements : nil } }
  }
}

/// Waits for a task to finish, giving up after a few seconds.
func finish(_ task: Task<Void, any Error>) async throws {
  let done = Recorder(
    AsyncStream<Void> { continuation in
      Task {
        _ = await task.result
        continuation.finish()
      }
    })
  _ = try await done.all()
  try await task.value
}

/// A transport whose received frames a test supplies, and which records the
/// frames it sends.
final class FakeTransport: CANTransport {
  let received: AsyncStream<CANFrame>
  let receive: AsyncStream<CANFrame>.Continuation
  /// The frames the node sent.
  let sent: Recorder<CANFrame>
  private let sentContinuation: AsyncStream<CANFrame>.Continuation
  private let failures: Mutex<Int>
  private let opens = Mutex(0)
  private let sendFailures = Mutex(0)

  struct OpenFailed: Error {}
  struct SendFailed: Error {}

  /// Makes the next sends fail.
  func failSends(_ count: Int) {
    sendFailures.withLock { $0 = count }
  }

  init(failingOpens: Int = 0) {
    (received, receive) = AsyncStream.makeStream(of: CANFrame.self)
    let (sentFrames, sentContinuation) = AsyncStream.makeStream(of: CANFrame.self)
    sent = Recorder(sentFrames)
    self.sentContinuation = sentContinuation
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
    let fails = sendFailures.withLock { failures in
      defer { failures = max(failures - 1, 0) }
      return failures > 0
    }
    if fails { throw SendFailed() }
    sentContinuation.yield(frame)
  }
}

private let claim: CANFrame = CANFrame(
  id: 0x18ee_ff17, data: [0x01, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0])

// The helpers give up after a few seconds; the time limit catches the rest.
@Suite("Node", .timeLimit(.minutes(1)))
struct NodeTests {
  @Test func claimsSendsAndReceives() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let messages = await node.messages()
    let run = Task { try await node.run() }
    let sent = transport.sent

    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(try await sent.next() == claim)

    clock.advance(to: 449)
    await #expect(throws: NodeError.claimingAddress) {
      try await node.send(PositionRapidUpdate(latitude: 1, longitude: 2))
    }
    clock.advance(to: 450)
    try await node.send(PositionRapidUpdate(latitude: 1, longitude: 2))
    #expect(try await sent.next()?.id == 0x09f8_0117)

    transport.receive.yield(CANFrame(id: 0x09f8_0142, data: [1, 2, 3, 4, 5, 6, 7, 8]))
    let received = Recorder(messages)
    let message = try #require(try await received.next())
    #expect(message.pgn == 129025)
    #expect(message.source == 0x42)
    #expect(message.data == [1, 2, 3, 4, 5, 6, 7, 8])
    #expect(message.timestamp == 450)

    transport.receive.finish()
    try await finish(run)
    #expect(try await received.next() == nil)
  }

  @Test func defendsItsAddress() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    let sent = transport.sent
    try await clock.waitForSleepers()
    clock.advance(to: 500)
    #expect(try await sent.next() == claim)

    // A lower NAME takes address 23, so the node claims 24.
    transport.receive.yield(
      CANFrame(id: 0x18ee_ff17, data: [0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]))
    #expect(try await sent.next() == CANFrame(id: 0x18ee_ff18, data: claim.data))
    #expect(await node.address == 24)

    run.cancel()
    transport.receive.finish()
    try await finish(run)
  }

  @Test func retriesOpeningEverySecond() async throws {
    let clock = ManualClock()
    let transport = FakeTransport(failingOpens: 2)
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    let sent = transport.sent

    try await clock.waitForSleepers()
    #expect(transport.openCount == 1)
    clock.advance(to: 1000)
    try await clock.waitForSleepers()
    #expect(transport.openCount == 2)
    clock.advance(to: 2000)
    try await clock.waitForSleepers()
    #expect(transport.openCount == 3)
    clock.advance(to: 2200)
    #expect(try await sent.next() == claim)

    transport.receive.finish()
    try await finish(run)
  }

  @Test func stopsOpeningWhenCancelled() async throws {
    let clock = ManualClock()
    let transport = FakeTransport(failingOpens: .max)
    let node = Node(transport: transport, clock: clock)
    let run = Task { try await node.run() }
    try await clock.waitForSleepers()
    run.cancel()
    await #expect(throws: CancellationError.self) { try await finish(run) }
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
    for _ in 0..<14 { frames.append(try #require(try await transport.sent.next())) }
    // Each fast packet's seven frames are sent together, in order.
    let sequences = frames.map { $0.data[0] >> 5 }
    #expect(
      sequences == Array(repeating: sequences[0], count: 7)
        + Array(repeating: sequences[7], count: 7))
    #expect(frames.map { $0.data[0] & 0x1f } == Array(0..<7) + Array(0..<7))

    transport.receive.finish()
    try await finish(run)
  }

  @Test func sendsTransportProtocolPacketsOnTime() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    let sent = transport.sent
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(try await sent.next() == claim)
    clock.advance(to: 450)

    try await node.send(
      Message(pgn: 126464, data: Array(0..<10), isTransportProtocol: true))
    #expect(try await sent.next()?.id == 0x18ec_ff17)
    // The node wakes itself for each data packet.
    try await clock.waitForSleepers()
    clock.advance(to: 500)
    #expect(try await sent.next() == CANFrame(id: 0x18eb_ff17, data: [1, 0, 1, 2, 3, 4, 5, 6]))
    try await clock.waitForSleepers()
    clock.advance(to: 550)
    #expect(
      try await sent.next()
        == CANFrame(id: 0x18eb_ff17, data: [2, 7, 8, 9, 0xff, 0xff, 0xff, 0xff]))

    transport.receive.finish()
    try await finish(run)
  }

  @Test func sendsProductInformationAgainAfterTheTransportFails() async throws {
    // Upstream's SendProductInformation tries again when its send fails:
    // 187 ms plus 8 ms for each unit of the address later.
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let run = Task { try await node.run() }
    let sent = transport.sent
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(try await sent.next() == claim)
    clock.advance(to: 450)

    transport.failSends(1)
    await #expect(throws: FakeTransport.SendFailed.self) {
      try await node.sendProductInformation()
    }
    try await clock.waitForSleepers()
    clock.advance(to: 450 + 187 + 23 * 8)
    #expect(try await sent.next()?.id == 0x19f0_1417)

    transport.receive.finish()
    try await finish(run)
  }

  @Test func sendsHeartbeatsAndAnswersRequests() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    await node.setISORequestHandler { pgn, requester, _ in
      pgn == 130306 ? [Message(pgn: 130306, destination: requester, data: [requester])] : nil
    }
    let run = Task { try await node.run() }
    let sent = transport.sent
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(try await sent.next() == claim)

    // Requests during the address claim go unanswered.
    clock.advance(to: 450)
    transport.receive.yield(CANFrame(id: 0x18ea_1742, data: [0x02, 0xfd, 0x01]))
    #expect(try await sent.next() == CANFrame(id: 0x19fd_0217, data: [0x42]))

    // The node wakes itself for the heartbeat, once its time has passed.
    clock.advance(to: 10200)
    try await clock.waitForSleepers()
    clock.advance(to: 10201)
    #expect(
      try await sent.next()
        == CANFrame(id: 0x1df0_1117, data: [0x60, 0xea, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff]))

    transport.receive.finish()
    try await finish(run)
  }

  @Test func hostsSeveralDevices() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let second = DeviceName(
      uniqueNumber: 2, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25)
    let node = Node(
      transport: transport, mode: .node,
      devices: [Node.Device(address: 23), Node.Device(address: 24, name: second)], clock: clock)
    let run = Task { try await node.run() }
    let sent = transport.sent
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    #expect(try await sent.next() == claim)
    #expect(try await sent.next()?.id == 0x18ee_ff18)
    clock.advance(to: 450)

    try await node.send(PositionRapidUpdate(latitude: 1, longitude: 2), from: 1)
    #expect(try await sent.next()?.id == 0x09f8_0118)
    await #expect(throws: NodeError.noSuchDevice(2)) {
      try await node.send(PositionRapidUpdate(latitude: 1, longitude: 2), from: 2)
    }
    #expect(await node.devices.map(\.address) == [23, 24])
    #expect(await node.devices[1].name == second)

    transport.receive.finish()
    try await finish(run)
  }

  @Test func reportsEventsAndSentMessages() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, mode: .node, address: 23, clock: clock)
    let events = Recorder(await node.events())
    let traffic = Recorder(await node.messages(includingSent: true))
    let run = Task { try await node.run() }
    try await clock.waitForSleepers()
    #expect(await !node.isOpen)
    clock.advance(to: 200)
    #expect(try await events.next() == .opened)
    #expect(await node.isOpen)
    #expect(try await traffic.next()?.pgn == ISOAddressClaim.pgn)

    // A lower NAME takes address 23.
    transport.receive.yield(
      CANFrame(id: 0x18ee_ff17, data: [0x00, 0x00, 0xc0, 0xff, 0x00, 0x82, 0x32, 0xc0]))
    #expect(try await events.next() == .addressChanged(device: 0))
    // The claim received, then the node's own claim from its new address.
    #expect(try await traffic.next()?.source == 23)
    #expect(try await traffic.next()?.source == 24)

    try await node.setInstances(device: 9, system: 3)
    #expect(try await events.next() == .deviceInformationChanged(device: 0))
    #expect(await node.name.deviceInstance == 9)
    #expect(await node.name.systemInstance == 3)

    try await node.setHeartbeatInterval(.seconds(5))
    #expect(try await events.next() == .deviceInformationChanged(device: 0))
    #expect(await node.devices[0].heartbeatInterval == .seconds(5))
    #expect(await node.isTransmitted(126993))
    #expect(await !node.isTransmitted(129025))

    transport.receive.finish()
    try await finish(run)
    #expect(try await events.next() == nil)
  }

  @Test func deliversEveryMessageToEverySubscriber() async throws {
    let clock = ManualClock()
    let transport = FakeTransport()
    let node = Node(transport: transport, clock: clock)
    let first = Recorder(await node.messages())
    let second = Recorder(await node.messages())
    let run = Task { try await node.run() }
    try await clock.waitForSleepers()
    clock.advance(to: 200)
    transport.receive.yield(CANFrame(id: 0x09f8_0142, data: [1, 2, 3, 4, 5, 6, 7, 8]))
    transport.receive.finish()
    try await finish(run)
    #expect(try await first.all().map(\.pgn) == [129025])
    #expect(try await second.all().map(\.pgn) == [129025])
  }
}
