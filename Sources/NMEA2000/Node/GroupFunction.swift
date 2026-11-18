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
/// ``Node/setGroupFunctionHandler(_:for:)``; it gets a ``ReceivedFunction`` and
/// returns the messages to send, which it builds with ``Acknowledgement``
/// and ``Reply``.
///
/// Ports the codes, error codes, parsers and message builders of
/// `N2kGroupFunction.h/.cpp`.
public enum GroupFunction {
  /// The group function PGN.
  public static let pgn: UInt32 = 126208

  /// The priority upstream sends group functions with.
  public static let priority: UInt8 = 3

  /// The function a group function message performs.
  ///
  /// Ports `tN2kGroupFunctionCode`. Values without a name here are kept in ``rawValue``.
  public struct FunctionCode: WireEnumeration {
    /// The value as it appears on the wire.
    public var rawValue: UInt8

    /// Creates a value from its wire representation.
    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// Asks the device to send the PGN, possibly filtered by field values, or to change its transmission interval.
    public static let request = Self(rawValue: 0)

    /// Sets fields of the PGN.
    public static let command = Self(rawValue: 1)

    /// Answers a request or command.
    public static let acknowledge = Self(rawValue: 2)

    /// Asks for field values.
    public static let read = Self(rawValue: 3)

    /// Answers a read.
    public static let readReply = Self(rawValue: 4)

    /// Writes field values.
    public static let write = Self(rawValue: 5)

    /// Answers a write.
    public static let writeReply = Self(rawValue: 6)

    public var description: String {
      switch self {
      case .request: "request"
      case .command: "command"
      case .acknowledge: "acknowledge"
      case .read: "read"
      case .readReply: "read reply"
      case .write: "write"
      case .writeReply: "write reply"
      default: "unknown (\(rawValue))"
      }
    }
  }
  /// How an acknowledgement answers the PGN.
  ///
  /// Ports `tN2kGroupFunctionPGNErrorCode`. Values without a name here are kept in ``rawValue``.
  public struct PGNError: WireEnumeration {
    /// The value as it appears on the wire.
    public var rawValue: UInt8

    /// Creates a value from its wire representation.
    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// The PGN is supported.
    public static let acknowledge = Self(rawValue: 0)

    /// The device doesn't support the PGN.
    public static let pgnNotSupported = Self(rawValue: 1)

    /// The device supports the PGN but can't send it now.
    public static let pgnTemporarilyNotAvailable = Self(rawValue: 2)

    /// The device refuses access.
    public static let accessDenied = Self(rawValue: 3)

    /// The device doesn't support the request or command.
    public static let requestOrCommandNotSupported = Self(rawValue: 4)

    /// The device doesn't support the definer tag.
    public static let definerTagNotSupported = Self(rawValue: 5)

    /// The device doesn't support reading or writing the PGN's fields.
    public static let readOrWriteNotSupported = Self(rawValue: 6)

    public var description: String {
      switch self {
      case .acknowledge: "acknowledge"
      case .pgnNotSupported: "PGN not supported"
      case .pgnTemporarilyNotAvailable: "PGN temporarily not available"
      case .accessDenied: "access denied"
      case .requestOrCommandNotSupported: "request or command not supported"
      case .definerTagNotSupported: "definer tag not supported"
      case .readOrWriteNotSupported: "read or write not supported"
      default: "unknown (\(rawValue))"
      }
    }
  }
  /// How an acknowledgement answers the transmission interval or priority.
  ///
  /// Ports `tN2kGroupFunctionTransmissionOrPriorityErrorCode`. Values without a name here are kept in ``rawValue``.
  public struct TransmissionError: WireEnumeration {
    /// The value as it appears on the wire.
    public var rawValue: UInt8

    /// Creates a value from its wire representation.
    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// The interval or priority is accepted.
    public static let acknowledge = Self(rawValue: 0)

    /// The device can't use that interval or priority.
    public static let intervalOrPriorityNotSupported = Self(rawValue: 1)

    /// The interval is shorter than the device measures at.
    public static let intervalLessThanMeasurementInterval = Self(rawValue: 2)

    /// The device refuses access.
    public static let accessDenied = Self(rawValue: 3)

    /// The device doesn't support the request.
    public static let requestNotSupported = Self(rawValue: 4)

    public var description: String {
      switch self {
      case .acknowledge: "acknowledge"
      case .intervalOrPriorityNotSupported: "interval or priority not supported"
      case .intervalLessThanMeasurementInterval: "interval less than measurement interval"
      case .accessDenied: "access denied"
      case .requestNotSupported: "request not supported"
      default: "unknown (\(rawValue))"
      }
    }
  }
  /// How an acknowledgement answers one parameter pair.
  ///
  /// Ports `tN2kGroupFunctionParameterErrorCode`. Values without a name here are kept in ``rawValue``.
  public struct ParameterError: WireEnumeration {
    /// The value as it appears on the wire.
    public var rawValue: UInt8

    /// Creates a value from its wire representation.
    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    /// The pair is accepted.
    public static let acknowledge = Self(rawValue: 0)

    /// The PGN has no such field.
    public static let invalidField = Self(rawValue: 1)

    /// The device can't act on the pair now.
    public static let temporarilyUnableToComply = Self(rawValue: 2)

    /// The value is out of range, or doesn't match a request's filter.
    public static let outOfRange = Self(rawValue: 3)

    /// The device refuses access.
    public static let accessDenied = Self(rawValue: 4)

    /// The device doesn't support the request or command.
    public static let notSupported = Self(rawValue: 5)

    /// The device doesn't support reading or writing the field.
    public static let readOrWriteNotSupported = Self(rawValue: 6)

    public var description: String {
      switch self {
      case .acknowledge: "acknowledge"
      case .invalidField: "invalid field"
      case .temporarilyUnableToComply: "temporarily unable to comply"
      case .outOfRange: "out of range"
      case .accessDenied: "access denied"
      case .notSupported: "not supported"
      case .readOrWriteNotSupported: "read or write not supported"
      default: "unknown (\(rawValue))"
      }
    }
  }
  /// A proprietary PGN's manufacturer, which reads, writes and their
  /// replies carry.
  public struct Manufacturer: Codable, Hashable, Sendable {
    /// The manufacturer code (11 bits).
    public var code: UInt16
    /// The industry group (3 bits).
    public var industryGroup: UInt8

    /// Creates a manufacturer.
    public init(code: UInt16, industryGroup: UInt8) {
      self.code = code
      self.industryGroup = industryGroup
    }
  }

  /// How a request asks to change the PGN's transmission interval.
  public enum IntervalChange: Hashable, Sendable {
    /// Keep the interval.
    case unchanged
    /// Restore the device's default interval.
    case restoreDefault
    /// Stop sending the PGN.
    case stop
    /// Send the PGN this often.
    case interval(Duration)
  }

  /// Where a request's parameter pairs start (`N2kgf_OffsetToRequestPairParameters`).
  static let requestPairsOffset = 11

  /// Where a command's parameter pairs start (`N2kgf_OffsetToCommandPairParameters`).
  static let commandPairsOffset = 6

  /// The transmission interval that leaves the interval unchanged.
  static let unchangedInterval: UInt32 = 0xffff_ffff

  /// The transmission interval that restores the default interval.
  static let defaultInterval: UInt32 = 0xffff_fffe

  /// The interval offset that leaves the offset unchanged.
  static let unchangedOffset: UInt16 = 0xffff

  /// The answer to a request's transmission interval and offset: acceptable
  /// if each is a special value (unchanged, default or off) or, where
  /// limits are given, within them.
  ///
  /// Ports `GetRequestGroupFunctionTransmissionOrPriorityErrorCode`.
  /// ``ReceivedFunction/RequestParameters/transmissionError(intervalLimits:maxOffset:)``
  /// is the public form.
  ///
  /// - Parameters:
  ///   - interval: The requested interval, in milliseconds.
  ///   - offset: The requested offset, in units of 10 ms.
  ///   - intervalLimits: The intervals the device supports, if any.
  ///   - maxOffset: The largest offset the device supports, if any.
  static func transmissionError(
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
  public struct ReceivedFunction: Sendable, Hashable {
    /// The group function message.
    public let message: Message

    /// The function code, from the message.
    public let code: FunctionCode

    /// The PGN the function is aimed at, from the message.
    public let pgn: UInt32

    /// The node's device the function is for.
    public let device: Node.DeviceID

    /// Creates a request from a group function message.
    public init(_ message: Message, device: Node.DeviceID) {
      self.message = message
      var reader = MessageReader(message)
      code = FunctionCode(rawValue: reader.readUInt8())
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

    /// A request's parameters.
    public struct RequestParameters: Hashable, Sendable {
      /// The transmission interval as sent: milliseconds, 0 to stop, or
      /// one of the special values `unchangedInterval` and
      /// `defaultInterval`.
      let interval: UInt32
      /// The interval offset as sent: units of 10 ms, or `unchangedOffset`.
      let offset: UInt16
      /// The number of parameter pairs.
      public let pairCount: UInt8

      init(interval: UInt32, offset: UInt16, pairCount: UInt8) {
        self.interval = interval
        self.offset = offset
        self.pairCount = pairCount
      }

      /// What the request asks for the interval.
      public var intervalChange: IntervalChange {
        switch interval {
        case GroupFunction.unchangedInterval: .unchanged
        case GroupFunction.defaultInterval: .restoreDefault
        case 0: .stop
        default: .interval(.milliseconds(interval))
        }
      }

      /// The new interval offset, or `nil` to keep it.
      public var offsetChange: Duration? {
        offset == GroupFunction.unchangedOffset ? nil : .milliseconds(Int(offset) * 10)
      }

      /// The answer to the request's transmission interval and offset:
      /// acceptable if each asks for no change, the default or a stop, or
      /// is within the limits given.
      ///
      /// Ports `GetRequestGroupFunctionTransmissionOrPriorityErrorCode`.
      ///
      /// - Parameters:
      ///   - intervalLimits: The intervals the device supports, or `nil` if
      ///     it can't change the interval.
      ///   - maxOffset: The largest offset the device supports, or `nil` if
      ///     it can't change the offset.
      public func transmissionError(
        intervalLimits: ClosedRange<Duration>? = nil, maxOffset: Duration? = nil
      ) -> TransmissionError {
        func milliseconds(_ duration: Duration) -> Int64 {
          let (seconds, attoseconds) = duration.components
          return seconds * 1000 + attoseconds / 1_000_000_000_000_000
        }
        let limits = intervalLimits.map {
          UInt32(
            clamping: milliseconds($0.lowerBound))...UInt32(
              clamping: milliseconds($0.upperBound))
        }
        return GroupFunction.transmissionError(
          interval: interval, offset: offset, intervalLimits: limits,
          maxOffset: maxOffset.map { UInt16(clamping: milliseconds($0) / 10) })
      }
    }

    /// A command's parameters.
    public struct CommandParameters: Hashable, Sendable {
      /// The priority setting: 0 to 7, 8 to leave it, or 9 to restore the
      /// default.
      public let prioritySetting: UInt8
      /// The number of parameter pairs.
      public let pairCount: UInt8
    }

    /// An acknowledgement's parameters.
    public struct AcknowledgementParameters: Hashable, Sendable {
      /// The answer to the PGN.
      public let pgnError: PGNError
      /// The answer to the transmission interval or priority.
      public let transmissionError: TransmissionError
      /// The number of parameter pairs.
      public let pairCount: UInt8
    }

    /// A read's or write's parameters.
    public struct ReadOrWriteParameters: Hashable, Sendable {
      /// For a proprietary PGN, its manufacturer.
      public let manufacturer: Manufacturer?
      /// The unique ID, which the reply repeats.
      public let uniqueID: UInt8
      /// The number of selection pairs.
      public let selectionPairCount: UInt8
      /// The number of parameter pairs.
      public let parameterPairCount: UInt8
    }

    /// A request's parameters (`ParseRequestParams`).
    public var requestParameters: RequestParameters {
      var reader = self.reader(at: 4)
      return RequestParameters(
        interval: reader.readUInt32(), offset: reader.readUInt16(), pairCount: reader.readUInt8())
    }

    /// A command's parameters (`ParseCommandParams`).
    public var commandParameters: CommandParameters {
      var reader = self.reader(at: 4)
      return CommandParameters(
        prioritySetting: reader.readUInt8() & 0x0f, pairCount: reader.readUInt8())
    }

    /// An acknowledgement's parameters (`ParseAcknowledgeParams`).
    public var acknowledgementParameters: AcknowledgementParameters {
      var reader = self.reader(at: 4)
      let errors = reader.readUInt8()
      return AcknowledgementParameters(
        pgnError: PGNError(rawValue: errors & 0x0f),
        transmissionError: TransmissionError(rawValue: errors >> 4), pairCount: reader.readUInt8())
    }

    /// A read's or write's parameters (`ParseReadOrWriteParams`).
    public var readOrWriteParameters: ReadOrWriteParameters {
      var reader = self.reader(at: 4)
      var manufacturer: Manufacturer?
      if isProprietary {
        let information = reader.readUInt16()
        manufacturer = Manufacturer(
          code: information & 0x07ff, industryGroup: UInt8(information >> 13 & 0x07))
      }
      return ReadOrWriteParameters(
        manufacturer: manufacturer, uniqueID: reader.readUInt8(),
        selectionPairCount: reader.readUInt8(), parameterPairCount: reader.readUInt8())
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

    /// The acknowledgement message, sent to `destination`, usually the
    /// requester. Parameter answers take four bits each, the first of a byte
    /// in the low bits, with an unused high half set to ones.
    public func makeMessage(destination: UInt8) -> Message {
      var data: [UInt8] = [
        FunctionCode.acknowledge.rawValue, UInt8(truncatingIfNeeded: pgn),
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

  /// A read or write reply being built: its header, then the selection and
  /// parameter pairs appended to ``writer``.
  ///
  /// ```swift
  /// var reply = GroupFunction.Reply(answering: request, selectionPairCount: 0, parameterPairCount: 1)
  /// reply.writer.appendUInt8(1)  // Field 1
  /// reply.writer.appendUInt8(42)
  /// return [reply.makeMessage(destination: request.requester)]
  /// ```
  ///
  /// Ports `SetStartReadReply` and `SetStartWriteReply`.
  public struct Reply: Sendable {
    /// The reply so far: the header, then whatever pairs have been
    /// appended.
    public var writer: MessageWriter

    /// Starts a reply.
    ///
    /// - Parameters:
    ///   - code: ``FunctionCode/readReply`` or ``FunctionCode/writeReply``.
    ///   - pgn: The PGN the reply is about.
    ///   - manufacturer: For a proprietary PGN, its manufacturer.
    ///   - uniqueID: The unique ID from the read or write.
    ///   - selectionPairCount: The number of selection pairs.
    ///   - parameterPairCount: The number of parameter pairs.
    public init(
      _ code: FunctionCode, pgn: UInt32, manufacturer: Manufacturer? = nil, uniqueID: UInt8,
      selectionPairCount: UInt8, parameterPairCount: UInt8
    ) {
      writer = MessageWriter()
      writer.appendUInt8(code.rawValue)
      writer.appendInt24(Int32(truncatingIfNeeded: pgn))
      if let manufacturer {
        writer.appendUInt16(
          UInt16(manufacturer.industryGroup) << 13 | 0x1800 | manufacturer.code & 0x07ff)
      }
      writer.appendUInt8(uniqueID)
      writer.appendUInt8(selectionPairCount)
      writer.appendUInt8(parameterPairCount)
    }

    /// Starts the reply to a read or write, with its PGN, manufacturer and
    /// unique ID.
    public init(
      answering request: ReceivedFunction, selectionPairCount: UInt8, parameterPairCount: UInt8
    ) {
      let parameters = request.readOrWriteParameters
      self.init(
        request.code == .write ? .writeReply : .readReply, pgn: request.pgn,
        manufacturer: parameters.manufacturer, uniqueID: parameters.uniqueID,
        selectionPairCount: selectionPairCount, parameterPairCount: parameterPairCount)
    }

    /// The reply message, sent to `destination`, usually the requester.
    public func makeMessage(destination: UInt8) -> Message {
      Message(
        pgn: GroupFunction.pgn, priority: GroupFunction.priority, destination: destination,
        data: writer.data)
    }
  }
}
