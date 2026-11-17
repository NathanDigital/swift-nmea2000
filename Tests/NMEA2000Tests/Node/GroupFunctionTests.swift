// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

import NMEA2000
import Testing

private func request(_ data: [UInt8], to destination: UInt8 = 0x17) -> GroupFunction.Request {
  GroupFunction.Request(
    Message(
      pgn: GroupFunction.pgn, priority: 3, source: 0x42, destination: destination, data: data),
    device: 1)
}

@Suite("Group function API")
struct GroupFunctionTests {
  @Test func startsRepliesAsUpstreamDoes() {
    // upstream-vectors "Group function reply starts"
    let read = GroupFunction.startReply(
      .readReply, pgn: 130816, proprietary: (manufacturerCode: 0x2a5, industryGroup: 4),
      uniqueID: 7, selectionPairCount: 1, parameterPairCount: 2)
    #expect(read.data == [0x04, 0x00, 0xff, 0x01, 0xa5, 0x9a, 0x07, 0x01, 0x02])
    let write = GroupFunction.startReply(
      .writeReply, pgn: 130310, uniqueID: 7, selectionPairCount: 1, parameterPairCount: 2)
    #expect(write.data == [0x06, 0x06, 0xfd, 0x01, 0x07, 0x01, 0x02])
  }

  @Test func readsTheHeader() {
    let request = request([0x01, 0x06, 0xfd, 0x01, 0xf9, 0x02])
    #expect(request.code == .command)
    #expect(request.pgn == 130310)
    #expect(request.device == 1)
    #expect(request.requester == 0x42)
    #expect(!request.isBroadcast)
    #expect(
      GroupFunction.Request(Message(pgn: GroupFunction.pgn, data: [9]), device: 0).code == nil)
  }

  @Test func readsRequestParameters() {
    var request = request([0x00, 0x06, 0xfd, 0x01, 0xd0, 0x07, 0, 0, 0x64, 0x00, 0x01, 0x07, 0x2a])
    let parameters = request.requestParameters
    #expect(parameters.interval == 2000)
    #expect(parameters.offset == 100)
    #expect(parameters.pairCount == 1)
    var pairs = request.pairs
    #expect(pairs.readUInt8() == 0x07)
    #expect(pairs.readUInt8() == 0x2a)
    request.message.data = [0x00, 0x06, 0xfd, 0x01]
    #expect(request.requestParameters == (0xffff_ffff, 0xffff, 0xff))
  }

  @Test func readsCommandParameters() {
    let request = request([0x01, 0x06, 0xfd, 0x01, 0xf9, 0x02, 0x03, 0x05])
    #expect(request.commandParameters == (9, 2))
    var pairs = request.pairs
    #expect(pairs.readUInt8() == 0x03)
  }

  @Test func readsAcknowledgementParameters() {
    let parameters = request([0x02, 0x06, 0xfd, 0x01, 0x12, 0x03]).acknowledgementParameters
    #expect(parameters.pgnError == .pgnTemporarilyNotAvailable)
    #expect(parameters.transmissionError == .intervalOrPriorityNotSupported)
    #expect(parameters.pairCount == 3)
    #expect(
      request([0x02, 0x06, 0xfd, 0x01, 0x0f, 0x00]).acknowledgementParameters.pgnError == nil)
  }

  @Test func readsReadAndWriteParameters() {
    let standard = request([0x03, 0x06, 0xfd, 0x01, 0x05, 0x00, 0x01, 0x09])
    #expect(standard.readOrWriteParameters == (nil, nil, 5, 0, 1))
    var pairs = standard.pairs
    #expect(pairs.readUInt8() == 0x09)
    // A proprietary PGN carries the manufacturer code and industry group.
    let proprietary = request([0x05, 0x00, 0xff, 0x01, 0xa5, 0x9a, 0x07, 0x01, 0x02, 0x0b])
    #expect(proprietary.readOrWriteParameters == (0x2a5, 4, 7, 1, 2))
    var proprietaryPairs = proprietary.pairs
    #expect(proprietaryPairs.readUInt8() == 0x0b)
  }

  @Test func checksTransmissionIntervals() {
    #expect(GroupFunction.transmissionError(interval: 0, offset: 0) == .acknowledge)
    #expect(
      GroupFunction.transmissionError(interval: 1000, offset: 0xffff)
        == .intervalOrPriorityNotSupported)
    #expect(
      GroupFunction.transmissionError(
        interval: 1000, offset: 50, intervalLimits: 1000...60000, maxOffset: 50) == .acknowledge)
    #expect(GroupFunction.isPriorityAccepted(8))
    #expect(!GroupFunction.isPriorityAccepted(3))
  }
}
