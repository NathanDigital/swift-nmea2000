// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126208, the group function: requests, commands, reads and writes
/// aimed at another PGN, and the acknowledgements that answer them.
///
/// ``Node`` answers group functions itself as upstream's default handlers
/// do. To answer them for your own PGNs, set a handler with
/// ``Node/setGroupFunctionHandler(_:for:)``; it gets a ``Request`` and
/// returns the messages to send, which it builds with ``Acknowledgement``
/// and ``startReply(_:pgn:proprietary:uniqueID:selectionPairCount:parameterPairCount:)``.
///
/// Ports the codes, error codes, parsers and message builders of
/// `N2kGroupFunction.h/.cpp`.
public enum GroupFunction {
  /// The group function PGN.
  public static let pgn: UInt32 = 126208

  /// The priority upstream sends group functions with.
  public static let priority: UInt8 = 3

  /// The function a group function message performs (`tN2kGroupFunctionCode`).
  public enum Code: UInt8, Sendable {
    /// Asks the device to send the PGN, possibly filtered by field values,
    /// or to change its transmission interval.
    case request = 0
    /// Sets fields of the PGN.
    case command = 1
    /// Answers a request or command.
    case acknowledge = 2
    /// Asks for field values.
    case read = 3
    /// Answers a read.
    case readReply = 4
    /// Writes field values.
    case write = 5
    /// Answers a write.
    case writeReply = 6
  }

  /// How an acknowledgement answers the PGN (`tN2kGroupFunctionPGNErrorCode`).
  public enum PGNError: UInt8, Sendable {
    /// The PGN is supported.
    case acknowledge = 0
    /// The device doesn't support the PGN.
    case pgnNotSupported = 1
    /// The device supports the PGN but can't send it now.
    case pgnTemporarilyNotAvailable = 2
    /// The device refuses access.
    case accessDenied = 3
    /// The device doesn't support the request or command.
    case requestOrCommandNotSupported = 4
    /// The device doesn't support the definer tag.
    case definerTagNotSupported = 5
    /// The device doesn't support reading or writing the PGN's fields.
    case readOrWriteNotSupported = 6
  }

  /// How an acknowledgement answers the transmission interval or priority
  /// (`tN2kGroupFunctionTransmissionOrPriorityErrorCode`).
  public enum TransmissionError: UInt8, Sendable {
    /// The interval or priority is accepted.
    case acknowledge = 0
    /// The device can't use that interval or priority.
    case intervalOrPriorityNotSupported = 1
    /// The interval is shorter than the device measures at.
    case intervalLessThanMeasurementInterval = 2
    /// The device refuses access.
    case accessDenied = 3
    /// The device doesn't support the request.
    case requestNotSupported = 4
  }

  /// How an acknowledgement answers one parameter pair
  /// (`tN2kGroupFunctionParameterErrorCode`).
  public enum ParameterError: UInt8, Sendable {
    /// The pair is accepted.
    case acknowledge = 0
    /// The PGN has no such field.
    case invalidField = 1
    /// The device can't act on the pair now.
    case temporarilyUnableToComply = 2
    /// The value is out of range, or doesn't match a request's filter.
    case outOfRange = 3
    /// The device refuses access.
    case accessDenied = 4
    /// The device doesn't support the request or command.
    case notSupported = 5
    /// The device doesn't support reading or writing the field.
    case readOrWriteNotSupported = 6
  }

  /// Where a request's parameter pairs start (`N2kgf_OffsetToRequestPairParameters`).
  static let requestPairsOffset = 11

  /// Where a command's parameter pairs start (`N2kgf_OffsetToCommandPairParameters`).
  static let commandPairsOffset = 6

  /// The transmission interval that leaves the interval unchanged.
  public static let unchangedInterval: UInt32 = 0xffff_ffff

  /// The transmission interval that restores the default interval.
  public static let defaultInterval: UInt32 = 0xffff_fffe

  /// The interval offset that leaves the offset unchanged.
  public static let unchangedOffset: UInt16 = 0xffff

  /// The answer to a request's transmission interval and offset: acceptable
  /// if each is a special value (unchanged, default or off) or, where
  /// limits are given, within them.
  ///
  /// Ports `GetRequestGroupFunctionTransmissionOrPriorityErrorCode`.
  ///
  /// - Parameters:
  ///   - interval: The requested interval, in milliseconds.
  ///   - offset: The requested offset, in units of 10 ms.
  ///   - intervalLimits: The intervals the device supports, if any.
  ///   - maxOffset: The largest offset the device supports, if any.
  public static func transmissionError(
    interval: UInt32, offset: UInt16, intervalLimits: ClosedRange<UInt32>? = nil,
    maxOffset: UInt16? = nil
  ) -> TransmissionError {
    let isIntervalAccepted =
      interval == unchangedInterval || interval == defaultInterval || interval == 0
      || intervalLimits?.contains(interval) == true
    let isOffsetAccepted =
      offset == unchangedOffset || offset == 0 || maxOffset.map { offset <= $0 } == true
    return isIntervalAccepted && isOffsetAccepted ? .acknowledge : .intervalOrPriorityNotSupported
  }

  /// Whether a command's priority setting is one upstream accepts: 8 (leave
  /// unchanged), 9 (restore default) or 15.
  public static func isPriorityAccepted(_ setting: UInt8) -> Bool {
    setting == 0x08 || setting == 0x0f || setting == 0x09
  }

  /// A group function received for one of the node's devices.
  ///
  /// The accessors read the parameters that follow the function code and
  /// PGN, as upstream's `ParseRequestParams`, `ParseCommandParams`,
  /// `ParseAcknowledgeParams` and `ParseReadOrWriteParams` do. Fields past
  /// the end of the payload read as all ones.
  public struct Request: Sendable, Hashable {
    /// The group function message.
    public var message: Message

    /// The function code, or `nil` for a code upstream doesn't define.
    public var code: Code?

    /// The PGN the function is aimed at.
    public var pgn: UInt32

    /// The index of the node's device the function is for.
    public var device: Int

    /// Creates a request from a group function message.
    public init(_ message: Message, device: Int) {
      self.message = message
      var reader = MessageReader(message)
      code = Code(rawValue: reader.readUInt8())
      pgn = reader.readUInt24()
      self.device = device
    }

    /// The requester's address.
    public var requester: UInt8 { message.source }

    /// Whether the function was broadcast. Commands, reads and writes may
    /// not be; upstream ignores those.
    public var isBroadcast: Bool { message.destination == Message.broadcastAddress }

    /// Whether the PGN is proprietary, which adds manufacturer fields to
    /// reads and writes.
    public var isProprietary: Bool { PGNCatalog.isProprietary(pgn) }

    /// A request's transmission interval in milliseconds, interval offset in
    /// units of 10 ms, and number of parameter pairs.
    public var requestParameters: (interval: UInt32, offset: UInt16, pairCount: UInt8) {
      var reader = self.reader(at: 4)
      return (reader.readUInt32(), reader.readUInt16(), reader.readUInt8())
    }

    /// A command's priority setting and number of parameter pairs.
    public var commandParameters: (prioritySetting: UInt8, pairCount: UInt8) {
      var reader = self.reader(at: 4)
      return (reader.readUInt8() & 0x0f, reader.readUInt8())
    }

    /// An acknowledgement's PGN and transmission answers, and number of
    /// parameter pairs.
    public var acknowledgementParameters:
      (pgnError: PGNError?, transmissionError: TransmissionError?, pairCount: UInt8)
    {
      var reader = self.reader(at: 4)
      let errors = reader.readUInt8()
      return (
        PGNError(rawValue: errors & 0x0f), TransmissionError(rawValue: errors >> 4),
        reader.readUInt8()
      )
    }

    /// A read's or write's fields: for a proprietary PGN the manufacturer
    /// code and industry group, then the unique ID and the numbers of
    /// selection and parameter pairs.
    public var readOrWriteParameters:
      (
        manufacturerCode: UInt16?, industryGroup: UInt8?, uniqueID: UInt8,
        selectionPairCount: UInt8, parameterPairCount: UInt8
      )
    {
      var reader = self.reader(at: 4)
      var manufacturerCode: UInt16?
      var industryGroup: UInt8?
      if isProprietary {
        let information = reader.readUInt16()
        manufacturerCode = information & 0x07ff
        industryGroup = UInt8(information >> 13 & 0x07)
      }
      return (
        manufacturerCode, industryGroup, reader.readUInt8(), reader.readUInt8(), reader.readUInt8()
      )
    }

    /// A reader positioned at the first parameter pair of a request,
    /// command, read or write (`StartParseRequestPairParameters`,
    /// `StartParseCommandPairParameters`, `StartParseReadOrWriteParameters`).
    public var pairs: MessageReader {
      switch code {
      case .request: reader(at: GroupFunction.requestPairsOffset)
      case .command: reader(at: GroupFunction.commandPairsOffset)
      default: reader(at: 4 + (isProprietary ? 5 : 3))
      }
    }

    func reader(at index: Int) -> MessageReader {
      var reader = MessageReader(message)
      reader.skip(index)
      return reader
    }
  }

  /// An acknowledgement being built, one parameter pair at a time.
  ///
  /// Ports `SetStartAcknowledge`, `AddAcknowledgeParameter`,
  /// `ChangePNGErrorCode`, `ChangeTransmissionOrPriorityErrorCode` and
  /// `SendAcknowledge`.
  public struct Acknowledgement: Sendable, Hashable {
    /// The PGN being answered.
    public var pgn: UInt32
    /// The answer to the PGN.
    public var pgnError: PGNError
    /// The answer to the transmission interval or priority.
    public var transmissionError: TransmissionError
    /// The number of parameter pairs in the function being answered.
    public var pairCount: UInt8
    /// The answer to each parameter pair, in order.
    public var parameterErrors: [ParameterError] = []

    /// Creates an acknowledgement.
    public init(
      pgn: UInt32, pgnError: PGNError, transmissionError: TransmissionError, pairCount: UInt8,
      parameterErrors: [ParameterError] = []
    ) {
      self.pgn = pgn
      self.pgnError = pgnError
      self.transmissionError = transmissionError
      self.pairCount = pairCount
      self.parameterErrors = parameterErrors
    }

    /// An acknowledgement whose parameter pairs all get the same answer, as
    /// `SendAcknowledge` builds it.
    public static func uniform(
      pgn: UInt32, pgnError: PGNError, transmissionError: TransmissionError, pairCount: UInt8 = 0,
      parameterError: ParameterError = .acknowledge
    ) -> Acknowledgement {
      Acknowledgement(
        pgn: pgn, pgnError: pgnError, transmissionError: transmissionError, pairCount: pairCount,
        parameterErrors: Array(repeating: parameterError, count: Int(pairCount)))
    }

    /// The acknowledgement message, sent to `destination`. Parameter answers
    /// take four bits each, the first of a byte in the low bits, with an
    /// unused high half set to ones.
    public func message(to destination: UInt8) -> Message {
      var data: [UInt8] = [
        Code.acknowledge.rawValue, UInt8(truncatingIfNeeded: pgn),
        UInt8(truncatingIfNeeded: pgn >> 8), UInt8(truncatingIfNeeded: pgn >> 16),
        pgnError.rawValue | transmissionError.rawValue << 4, pairCount,
      ]
      for (index, error) in parameterErrors.enumerated() {
        if index.isMultiple(of: 2) {
          data.append(error.rawValue | 0xf0)
        } else {
          data[data.count - 1] = data[data.count - 1] & 0x0f | error.rawValue << 4
        }
      }
      return Message(
        pgn: GroupFunction.pgn, priority: GroupFunction.priority, destination: destination,
        data: data)
    }
  }

  /// Starts a read or write reply; append the parameter pairs to the writer,
  /// then send `Message(pgn: GroupFunction.pgn, priority:
  /// GroupFunction.priority, destination: requester, data: writer.data)`.
  ///
  /// Ports `SetStartReadReply` and `SetStartWriteReply`.
  ///
  /// - Parameters:
  ///   - code: ``Code/readReply`` or ``Code/writeReply``.
  ///   - pgn: The PGN the reply is about.
  ///   - proprietary: For a proprietary PGN, the manufacturer code and
  ///     industry group to include.
  ///   - uniqueID: The unique ID from the read or write.
  ///   - selectionPairCount: The number of selection pairs.
  ///   - parameterPairCount: The number of parameter pairs.
  public static func startReply(
    _ code: Code, pgn: UInt32, proprietary: (manufacturerCode: UInt16, industryGroup: UInt8)? = nil,
    uniqueID: UInt8, selectionPairCount: UInt8, parameterPairCount: UInt8
  ) -> MessageWriter {
    var writer = MessageWriter()
    writer.appendUInt8(code.rawValue)
    writer.appendInt24(Int32(truncatingIfNeeded: pgn))
    if let proprietary {
      writer.appendUInt16(
        UInt16(proprietary.industryGroup) << 13 | 0x1800 | proprietary.manufacturerCode & 0x07ff)
    }
    writer.appendUInt8(uniqueID)
    writer.appendUInt8(selectionPairCount)
    writer.appendUInt8(parameterPairCount)
    return writer
  }
}
