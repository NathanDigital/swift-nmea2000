// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 126208, the group function: requests, commands, reads and writes
/// aimed at another PGN, and the acknowledgements that answer them.
///
/// Ports the codes, error codes and message layouts of
/// `N2kGroupFunction.h/.cpp`.
enum GroupFunction {
  static let pgn: UInt32 = 126208

  /// The priority upstream sends group functions with.
  static let priority: UInt8 = 3

  /// The function a group function message performs (`tN2kGroupFunctionCode`).
  enum Code: UInt8 {
    case request = 0
    case command = 1
    case acknowledge = 2
    case read = 3
    case readReply = 4
    case write = 5
    case writeReply = 6
  }

  /// How an acknowledgement answers the PGN (`tN2kGroupFunctionPGNErrorCode`).
  enum PGNError: UInt8 {
    case acknowledge = 0
    case pgnNotSupported = 1
    case pgnTemporarilyNotAvailable = 2
    case accessDenied = 3
    case requestOrCommandNotSupported = 4
    case definerTagNotSupported = 5
    case readOrWriteNotSupported = 6
  }

  /// How an acknowledgement answers the transmission interval or priority
  /// (`tN2kGroupFunctionTransmissionOrPriorityErrorCode`).
  enum TransmissionError: UInt8 {
    case acknowledge = 0
    case intervalOrPriorityNotSupported = 1
    case intervalLessThanMeasurementInterval = 2
    case accessDenied = 3
    case requestNotSupported = 4
  }

  /// How an acknowledgement answers one parameter pair
  /// (`tN2kGroupFunctionParameterErrorCode`).
  enum ParameterError: UInt8 {
    case acknowledge = 0
    case invalidField = 1
    case temporarilyUnableToComply = 2
    case outOfRange = 3
    case accessDenied = 4
    case notSupported = 5
    case readOrWriteNotSupported = 6
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
  /// if each is a special value or, where limits are given, within them.
  ///
  /// Ports `GetRequestGroupFunctionTransmissionOrPriorityErrorCode`.
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
  static func isPriorityAccepted(_ setting: UInt8) -> Bool {
    setting == 0x08 || setting == 0x0f || setting == 0x09
  }

  /// An acknowledgement being built, one parameter pair at a time.
  ///
  /// Ports `SetStartAcknowledge`, `AddAcknowledgeParameter` and
  /// `SendAcknowledge`.
  struct Acknowledgement {
    var pgn: UInt32
    var pgnError: PGNError
    var transmissionError: TransmissionError
    var pairCount: UInt8
    var parameterErrors: [ParameterError] = []

    /// An acknowledgement whose parameter pairs all get the same answer.
    static func uniform(
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
    func message(to destination: UInt8) -> Message {
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
}
