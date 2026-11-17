// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Group function handling: the default handler every upstream node has for
/// any PGN, and the handlers for the network management PGNs (60928, 126464,
/// 126993, 126996 and 126998).
///
/// Ports `tNMEA2000::HandleGroupFunction`, `tN2kGroupFunctionHandler` and
/// `N2kGroupFunctionDefaultHandlers.cpp`.
extension NodeEngine {
  /// The parts of a group function every handler reads.
  struct GroupFunctionRequest {
    var message: Message
    var code: UInt8
    var pgn: UInt32
    /// The node's device the request is for.
    var device: Int

    var requester: UInt8 { message.source }
    var isBroadcast: Bool { message.destination == Message.broadcastAddress }

    /// A reader positioned at offset `index` of the payload.
    func reader(at index: Int) -> MessageReader {
      var reader = MessageReader(message)
      reader.skip(index)
      return reader
    }

    /// Where a reply that sends the PGN's data goes: back to the requester,
    /// or to everyone if the request was broadcast by transport protocol.
    var replyDestination: UInt8 {
      message.isTransportProtocol && isBroadcast ? Message.broadcastAddress : requester
    }
  }

  /// Handles a group function sent to one of the node's devices, or
  /// broadcast to all of them.
  ///
  /// Ports `tNMEA2000::HandleGroupFunction` and `RespondGroupFunction`.
  mutating func handleGroupFunction(_ message: Message, at now: UInt64) -> [CANFrame] {
    var reader = MessageReader(message)
    let code = reader.readUInt8()
    let pgn = reader.readUInt24()
    return recipients(of: message).flatMap {
      handleGroupFunction(
        GroupFunctionRequest(message: message, code: code, pgn: pgn, device: $0), at: now)
    }
  }

  /// Handles a group function for one device.
  ///
  /// Ports `tN2kGroupFunctionHandler::Handle`.
  private mutating func handleGroupFunction(_ request: GroupFunctionRequest, at now: UInt64)
    -> [CANFrame]
  {
    // The handlers for network management PGNs know those aren't
    // proprietary; the default handler checks the requested PGN.
    let isProprietary =
      !Self.networkManagementPGNs.contains(request.pgn)
      && PGNCatalog.isProprietary(request.pgn)

    switch GroupFunction.Code(rawValue: request.code) {
    case .request:
      var params = request.reader(at: 4)
      let interval = params.readUInt32()
      let offset = params.readUInt16()
      let pairCount = params.readUInt8()
      return handleRequest(
        request, interval: interval, offset: offset, pairCount: pairCount, at: now)
    case .command:
      // Commands, reads and writes may not be broadcast.
      guard !request.isBroadcast else { return [] }
      var params = request.reader(at: 4)
      let priority = params.readUInt8() & 0x0f
      let pairCount = params.readUInt8()
      return handleCommand(request, priority: priority, pairCount: pairCount, at: now)
    case .read, .write:
      guard !request.isBroadcast else { return [] }
      var params = request.reader(at: isProprietary ? 6 : 4)
      _ = params.readUInt8()  // Unique ID
      _ = params.readUInt8()  // Number of selection pairs
      let pairCount = params.readUInt8()
      // Upstream's handlers don't support reading or writing fields.
      return sendAcknowledgement(
        .uniform(
          pgn: request.pgn,
          pgnError: isTransmitted(request.pgn, by: request.device)
            ? .readOrWriteNotSupported : .pgnNotSupported,
          transmissionError: .acknowledge, pairCount: pairCount),
        to: request.requester, from: request.device, at: now)
    case .acknowledge, .readReply, .writeReply, nil:
      return []
    }
  }

  /// The PGNs with handlers of their own.
  static let networkManagementPGNs: Set<UInt32> = [60928, 126464, 126993, 126996, 126998]

  /// Whether a device transmits a PGN (`IsTxPGN`).
  func isTransmitted(_ pgn: UInt32, by device: Int) -> Bool {
    MessageFramer.defaultTransmitPGNs.contains(pgn) || devices[device].transmitPGNs.contains(pgn)
  }

  private mutating func sendAcknowledgement(
    _ acknowledgement: GroupFunction.Acknowledgement, to destination: UInt8, from device: Int,
    at now: UInt64
  ) -> [CANFrame] {
    sendAll([acknowledgement.message(to: destination)], from: device, at: now)
  }

  // MARK: - Requests

  private mutating func handleRequest(
    _ request: GroupFunctionRequest, interval: UInt32, offset: UInt16, pairCount: UInt8,
    at now: UInt64
  ) -> [CANFrame] {
    switch request.pgn {
    case ISOAddressClaim.pgn, PGNList.pgn, ProductInformation.pgn, ConfigurationInformation.pgn:
      return handleFilteredRequest(
        request, interval: interval, offset: offset, pairCount: pairCount, at: now)
    case Heartbeat.pgn:
      return handleHeartbeatRequest(
        request, interval: interval, offset: offset, pairCount: pairCount, at: now)
    default:
      return handleDefaultRequest(
        request, interval: interval, offset: offset, pairCount: pairCount, at: now)
    }
  }

  /// Answers a request for a PGN without a handler of its own: the node
  /// can't send other PGNs on request, so it acknowledges what it can.
  ///
  /// Ports `tN2kGroupFunctionHandler::HandleRequest`.
  private mutating func handleDefaultRequest(
    _ request: GroupFunctionRequest, interval: UInt32, offset: UInt16, pairCount: UInt8,
    at now: UInt64
  ) -> [CANFrame] {
    var transmissionError = GroupFunction.transmissionError(interval: interval, offset: offset)
    var pgnError = GroupFunction.PGNError.pgnNotSupported
    if !isTransmitted(request.pgn, by: request.device) {
      transmissionError = .acknowledge
    } else if transmissionError == .intervalOrPriorityNotSupported {
      pgnError = .acknowledge
    } else {
      pgnError = .pgnTemporarilyNotAvailable
      transmissionError = .acknowledge
    }
    guard !request.isBroadcast else { return [] }
    return sendAcknowledgement(
      .uniform(
        pgn: request.pgn, pgnError: pgnError, transmissionError: transmissionError,
        pairCount: pairCount),
      to: request.requester, from: request.device, at: now)
  }

  /// Answers a request for a network management PGN whose parameter pairs
  /// filter on the PGN's fields: if every field matches, the node sends the
  /// PGN; otherwise it acknowledges with what didn't match, unless the
  /// request was broadcast.
  ///
  /// Ports `HandleRequest` of the default handlers for 60928, 126464,
  /// 126996 and 126998, with one deliberate fix: upstream compares the
  /// software version, model version and serial code filters of 126996 with
  /// the model ID.
  private mutating func handleFilteredRequest(
    _ request: GroupFunctionRequest, interval: UInt32, offset: UInt16, pairCount: UInt8,
    at now: UInt64
  ) -> [CANFrame] {
    let transmissionError = GroupFunction.transmissionError(interval: interval, offset: offset)
    var acknowledgement = GroupFunction.Acknowledgement(
      pgn: request.pgn, pgnError: .acknowledge, transmissionError: transmissionError,
      pairCount: pairCount)
    var filter = FieldFilter()
    var listKind: PGNList.Kind?
    var fields = request.reader(at: GroupFunction.requestPairsOffset)
    var foundInvalidField = false
    var index = 0
    // A broadcast request stops at the first field that doesn't match.
    while index < pairCount && (filter.matches || !request.isBroadcast) {
      let error: GroupFunction.ParameterError
      if foundInvalidField {
        // Without knowing the invalid field's length, the rest can't be read.
        error = .temporarilyUnableToComply
      } else if let fieldError = matchField(
        fields.readUInt8(), of: request.pgn, for: request.device, from: &fields, in: &filter,
        listKind: &listKind)
      {
        error = fieldError
      } else {
        error = .invalidField
        filter.matches = false
        foundInvalidField = true
      }
      acknowledgement.parameterErrors.append(error)
      index += 1
    }

    guard filter.matches && transmissionError == .acknowledge else {
      return request.isBroadcast
        ? []
        : sendAcknowledgement(acknowledgement, to: request.requester, from: request.device, at: now)
    }
    let destination = request.replyDestination
    let usesTransportProtocol = request.message.isTransportProtocol
    switch request.pgn {
    case ISOAddressClaim.pgn:
      // Upstream puts the claim off by 2 ms, as some test tools couldn't
      // take a faster reply.
      devices[request.device].pendingClaim = now + 2
      return []
    case PGNList.pgn:
      var lists: [Message] = []
      if listKind != .receive { lists.append(transmitList(of: request.device, to: destination)) }
      if listKind != .transmit { lists.append(receiveList(of: request.device, to: destination)) }
      for index in lists.indices { lists[index].isTransportProtocol = usesTransportProtocol }
      return sendAll(lists, from: request.device, at: now)
    case ProductInformation.pgn:
      return sendProductInformation(
        from: request.device, to: destination, transportProtocol: usesTransportProtocol, at: now)
    default:
      return sendConfigurationInformation(
        from: request.device, to: destination, transportProtocol: usesTransportProtocol, at: now)
    }
  }

  /// Whether a request's field filters still match, and the answer to each.
  struct FieldFilter {
    var matches = true

    /// Matches a numeric field against the device's value under a mask
    /// (`MatchRequestField`).
    mutating func match(_ value: UInt32, _ current: UInt32, mask: UInt32)
      -> GroupFunction.ParameterError
    {
      guard value & mask == current else {
        matches = false
        return .outOfRange
      }
      return .acknowledge
    }

    /// Matches a string field. Upstream reports any string field after a
    /// mismatch as out of range too.
    mutating func match(_ value: String, _ current: String) -> GroupFunction.ParameterError {
      matches = matches && value == current
      return matches ? .acknowledge : .outOfRange
    }
  }

  /// Reads one field's value and matches it, returning the answer, or `nil`
  /// if the PGN has no such field.
  private func matchField(
    _ field: UInt8, of pgn: UInt32, for device: Int, from reader: inout MessageReader,
    in filter: inout FieldFilter, listKind: inout PGNList.Kind?
  ) -> GroupFunction.ParameterError? {
    let name = devices[device].name
    switch (pgn, field) {
    case (ISOAddressClaim.pgn, 1):
      return filter.match(reader.readUInt24(), name.uniqueNumber, mask: 0x1f_ffff)
    case (ISOAddressClaim.pgn, 2):
      return filter.match(UInt32(reader.readUInt16()), UInt32(name.manufacturerCode), mask: 0x7ff)
    case (ISOAddressClaim.pgn, 3):
      return filter.match(UInt32(reader.readUInt8()), UInt32(name.deviceInstanceLower), mask: 0x07)
    case (ISOAddressClaim.pgn, 4):
      return filter.match(UInt32(reader.readUInt8()), UInt32(name.deviceInstanceUpper), mask: 0x1f)
    case (ISOAddressClaim.pgn, 5):
      return filter.match(UInt32(reader.readUInt8()), UInt32(name.deviceFunction), mask: 0xff)
    case (ISOAddressClaim.pgn, 7):
      return filter.match(UInt32(reader.readUInt8()), UInt32(name.deviceClass), mask: 0x7f)
    case (ISOAddressClaim.pgn, 8):
      return filter.match(UInt32(reader.readUInt8()), UInt32(name.systemInstance), mask: 0x0f)
    case (ISOAddressClaim.pgn, 9):
      return filter.match(UInt32(reader.readUInt8()), UInt32(name.industryGroup), mask: 0x07)
    case (ISOAddressClaim.pgn, 6), (ISOAddressClaim.pgn, 10):
      // Reserved, and arbitrary address capable: read and accepted.
      _ = reader.readUInt8()
      return .acknowledge
    case (PGNList.pgn, 1):
      let kind = PGNList.Kind(rawValue: reader.readUInt8())
      listKind = kind
      guard kind == .transmit || kind == .receive else {
        filter.matches = false
        return .outOfRange
      }
      return .acknowledge
    case (ProductInformation.pgn, 1...8):
      return matchProductField(
        field, of: productInformation(of: device), from: &reader, in: &filter)
    case (ConfigurationInformation.pgn, 1...3):
      let value = Self.configurationText(reader.readVariableString() ?? "")
      let configuration = configurationInformation
      let current =
        switch field {
        case 1: configuration?.installationDescription1
        case 2: configuration?.installationDescription2
        default: configuration?.manufacturerInformation
        }
      return filter.match(value, Self.configurationText(current ?? ""))
    default:
      return nil
    }
  }

  private func matchProductField(
    _ field: UInt8, of product: ProductInformation, from reader: inout MessageReader,
    in filter: inout FieldFilter
  ) -> GroupFunction.ParameterError {
    let count = ProductInformation.stringFieldCount
    switch field {
    case 1:
      return filter.match(
        UInt32(reader.readUInt16()), UInt32(product.nmea2000Version), mask: 0xffff)
    case 2:
      return filter.match(UInt32(reader.readUInt16()), UInt32(product.productCode), mask: 0xffff)
    case 3:
      return filter.match(
        reader.readFixedString(count: count) ?? "", Self.productText(product.modelID))
    case 4:
      return filter.match(
        reader.readFixedString(count: count) ?? "", Self.productText(product.softwareVersion))
    case 5:
      return filter.match(
        reader.readFixedString(count: count) ?? "", Self.productText(product.modelVersion))
    case 6:
      return filter.match(
        reader.readFixedString(count: count) ?? "", Self.productText(product.modelSerialCode))
    case 7:
      return filter.match(
        UInt32(reader.readUInt8()), UInt32(product.certificationLevel), mask: 0xff)
    default:
      return filter.match(UInt32(reader.readUInt8()), UInt32(product.loadEquivalency), mask: 0xff)
    }
  }

  /// A product information string as it goes on the wire, cut to its field.
  static func productText(_ text: String) -> String {
    String(decoding: text.utf8.prefix(ProductInformation.stringFieldCount), as: UTF8.self)
  }

  /// A configuration information string as upstream stores it: at most 70
  /// bytes, the size of its buffer less the terminating NUL.
  static func configurationText(_ text: String) -> String {
    String(decoding: text.utf8.prefix(ConfigurationInformation.maxFieldLength - 1), as: UTF8.self)
  }

  /// Ports `SendTxPGNList`.
  func transmitList(of device: Int, to destination: UInt8) -> Message {
    let pgns = MessageFramer.defaultTransmitPGNs + devices[device].transmitPGNs
    return PGNList(kind: .transmit, pgns: Array(pgns.prefix(Self.maxPGNsInList)))
      .makeMessage(destination: destination)
  }

  /// Ports `SendRxPGNList`.
  func receiveList(of device: Int, to destination: UInt8) -> Message {
    let pgns = Self.defaultReceivePGNs + devices[device].receivePGNs
    return PGNList(kind: .receive, pgns: Array(pgns.prefix(Self.maxPGNsInList)))
      .makeMessage(destination: destination)
  }

  /// The configuration information, or a negative acknowledgement if the
  /// node has none (`SendConfigurationInformation`).
  func configurationReply(to destination: UInt8) -> Message {
    configurationInformation?.makeMessage(destination: destination)
      ?? ISOAcknowledgement(control: 1, pgn: ConfigurationInformation.pgn)
      .makeMessage(destination: destination)
  }

  /// Sets the heartbeat interval or offset from a request, or answers why
  /// not.
  ///
  /// Ports `tN2kGroupFunctionHandlerForPGN126993::HandleRequest`.
  private mutating func handleHeartbeatRequest(
    _ request: GroupFunctionRequest, interval: UInt32, offset: UInt16, pairCount: UInt8,
    at now: UInt64
  ) -> [CANFrame] {
    var transmissionError = GroupFunction.transmissionError(
      interval: interval, offset: offset, intervalLimits: 1000...60000, maxOffset: 6000)
    // The heartbeat can't be turned off.
    if interval == 0 { transmissionError = .intervalOrPriorityNotSupported }
    guard pairCount == 0 else {
      guard !request.isBroadcast else { return [] }
      return sendAcknowledgement(
        .uniform(
          pgn: Heartbeat.pgn, pgnError: .acknowledge, transmissionError: transmissionError,
          pairCount: pairCount, parameterError: .notSupported),
        to: request.requester, from: request.device, at: now)
    }
    if interval == GroupFunction.unchangedInterval && offset == GroupFunction.unchangedOffset {
      // Asking for no change is prohibited, so the default answer applies.
      return handleDefaultRequest(
        request, interval: interval, offset: offset, pairCount: 0, at: now)
    }
    guard transmissionError == .acknowledge else {
      guard !request.isBroadcast else { return [] }
      return sendAcknowledgement(
        .uniform(pgn: Heartbeat.pgn, pgnError: .acknowledge, transmissionError: transmissionError),
        to: request.requester, from: request.device, at: now)
    }
    // The offset comes in units of 10 ms.
    let newOffset =
      offset == GroupFunction.unchangedOffset || offset == 0 ? nil : UInt64(offset) * 10
    let period: UInt64? =
      switch interval {
      case GroupFunction.unchangedInterval: devices[request.device].heartbeat?.period
      case GroupFunction.defaultInterval: 60000
      default: UInt64(interval)
      }
    setHeartbeat(of: request.device, interval: period, offset: newOffset, at: now)
    guard let schedule = devices[request.device].heartbeat else { return [] }
    return sendAll(
      [Heartbeat(interval: Double(schedule.period) / 1000, sequenceCounter: nil).makeMessage()],
      from: request.device, at: now)
  }

  // MARK: - Commands

  private mutating func handleCommand(
    _ request: GroupFunctionRequest, priority: UInt8, pairCount: UInt8, at now: UInt64
  ) -> [CANFrame] {
    let transmissionError: GroupFunction.TransmissionError =
      GroupFunction.isPriorityAccepted(priority) ? .acknowledge : .intervalOrPriorityNotSupported
    switch request.pgn {
    case ISOAddressClaim.pgn:
      return handleAddressClaimCommand(request, pairCount: pairCount, at: now)
    case ConfigurationInformation.pgn:
      return handleConfigurationCommand(
        request, transmissionError: transmissionError, pairCount: pairCount, at: now)
    default:
      // Upstream's heartbeat handler says it doesn't support the PGN.
      let isSupported =
        request.pgn != Heartbeat.pgn && isTransmitted(request.pgn, by: request.device)
      return sendAcknowledgement(
        .uniform(
          pgn: request.pgn, pgnError: isSupported ? .acknowledge : .pgnNotSupported,
          transmissionError: transmissionError, pairCount: pairCount),
        to: request.requester, from: request.device, at: now)
    }
  }

  /// Sets the device instance and system instance in the NAME, then claims
  /// the address again with it.
  ///
  /// Ports `tN2kGroupFunctionHandlerForPGN60928::HandleCommand`. Upstream
  /// checks the priority setting after starting its acknowledgement, so it
  /// never reports one it doesn't support; this port keeps that. A field it
  /// doesn't know isn't skipped, so the pairs after it are read from the
  /// wrong place, as upstream reads them.
  private mutating func handleAddressClaimCommand(
    _ request: GroupFunctionRequest, pairCount: UInt8, at now: UInt64
  ) -> [CANFrame] {
    var acknowledgement = GroupFunction.Acknowledgement(
      pgn: ISOAddressClaim.pgn, pgnError: .acknowledge, transmissionError: .acknowledge,
      pairCount: pairCount)
    var fields = request.reader(at: GroupFunction.commandPairsOffset)
    var lower: UInt8?
    var upper: UInt8?
    var system: UInt8?
    for _ in 0..<pairCount {
      var error = GroupFunction.ParameterError.acknowledge
      switch fields.readUInt8() {
      case 3: lower = fields.readUInt8() & 0x07
      case 4: upper = fields.readUInt8() & 0x1f
      case 8: system = fields.readUInt8() & 0x0f
      default: error = .invalidField
      }
      acknowledgement.parameterErrors.append(error)
    }
    let frames = sendAcknowledgement(
      acknowledgement, to: request.requester, from: request.device, at: now)
    setInstances(of: request.device, lower: lower, upper: upper, system: system, at: now)
    return frames
  }

  /// Sets the installation descriptions.
  ///
  /// Ports `tN2kGroupFunctionHandlerForPGN126998::HandleCommand`. As in the
  /// address claim command, an unknown field isn't skipped.
  private mutating func handleConfigurationCommand(
    _ request: GroupFunctionRequest, transmissionError: GroupFunction.TransmissionError,
    pairCount: UInt8, at now: UInt64
  ) -> [CANFrame] {
    var acknowledgement = GroupFunction.Acknowledgement(
      pgn: ConfigurationInformation.pgn, pgnError: .acknowledge,
      transmissionError: transmissionError, pairCount: pairCount)
    var fields = request.reader(at: GroupFunction.commandPairsOffset)
    var configuration =
      configurationInformation
      ?? ConfigurationInformation(
        manufacturerInformation: "", installationDescription1: "", installationDescription2: "")
    for _ in 0..<pairCount {
      switch fields.readUInt8() {
      case 1:
        configuration.installationDescription1 = Self.configurationText(
          fields.readVariableString() ?? "")
        acknowledgement.parameterErrors.append(.acknowledge)
        configurationInformation = configuration
        events.append(.installationDescriptionChanged)
      case 2:
        configuration.installationDescription2 = Self.configurationText(
          fields.readVariableString() ?? "")
        acknowledgement.parameterErrors.append(.acknowledge)
        configurationInformation = configuration
        events.append(.installationDescriptionChanged)
      default:
        acknowledgement.parameterErrors.append(.invalidField)
      }
    }
    return sendAcknowledgement(
      acknowledgement, to: request.requester, from: request.device, at: now)
  }
}
