// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The devices on the bus, learned from the messages they send.
///
/// The list follows address claims to learn each device's NAME, and asks
/// each device in turn for its product information, configuration
/// information and PGN lists. It makes at most one request per message
/// received, and only once a device has been known for a second, so it
/// doesn't flood the bus; each request is retried up to four times.
///
/// A ``Node`` keeps one when created with `discoversDevices: true`. To
/// drive one yourself, pass it every received message with ``handle(_:at:sending:)``.
///
/// Ports `tN2kDeviceList`.
public struct DeviceList: Sendable {
  /// A device on the bus.
  public struct Device: Sendable, Hashable {
    /// The device's address.
    public internal(set) var source: UInt8

    /// The device's NAME, or `nil` until it has claimed its address.
    public var name: DeviceName? { rawName == 0 ? nil : DeviceName(rawValue: rawName) }

    /// The device's product information, or `nil` until it has sent it.
    public internal(set) var productInformation: ProductInformation?

    /// The device's configuration information, or `nil` until it has sent
    /// it.
    public internal(set) var configurationInformation: ConfigurationInformation?

    /// The PGNs the device transmits, or `nil` until it has sent the list.
    public internal(set) var transmitPGNs: [UInt32]?

    /// The PGNs the device receives, or `nil` until it has sent the list.
    public internal(set) var receivePGNs: [UInt32]?

    /// When the device last sent a message, in the time passed to
    /// ``DeviceList/handle(_:at:sending:)``.
    public internal(set) var lastMessageTime: UInt32 = 0

    var rawName: UInt64
    let createTime: UInt32
    var hasProductInformation = false
    var hasConfigurationInformation = false
    var nameRequests: UInt8 = 0
    var productRequestTime: UInt32 = 0
    var productRequests: UInt8 = 0
    var configurationRequestTime: UInt32 = 0
    var configurationRequests: UInt8 = 0
    var pgnListRequestTime: UInt32 = 0
    var pgnListRequests: UInt8 = 0

    init(name: UInt64, source: UInt8, at time: UInt32) {
      rawName = name
      self.source = source
      createTime = time
    }

    var shouldRequestName: Bool { rawName == 0 && nameRequests < 20 }

    var shouldRequestProductInformation: Bool { !hasProductInformation && productRequests < 4 }

    func isReadyToRequestProductInformation(at now: UInt32) -> Bool {
      shouldRequestProductInformation
        && hasElapsed(DeviceList.requestInterval, since: productRequestTime, at: now)
        && hasElapsed(DeviceList.firstRequestDelay, since: createTime, at: now)
    }

    var shouldRequestConfigurationInformation: Bool {
      !hasConfigurationInformation && configurationRequests < 4
    }

    /// Upstream tests these intervals with `>` rather than `N2kHasElapsed`.
    func isReadyToRequestConfigurationInformation(at now: UInt32) -> Bool {
      shouldRequestConfigurationInformation
        && now &- configurationRequestTime > DeviceList.requestInterval
        && now &- createTime > DeviceList.firstRequestDelay
    }

    var shouldRequestPGNLists: Bool {
      (transmitPGNs == nil || receivePGNs == nil) && pgnListRequests < 4
    }

    func isReadyToRequestPGNLists(at now: UInt32) -> Bool {
      shouldRequestPGNLists
        && hasElapsed(DeviceList.requestInterval, since: pgnListRequestTime, at: now)
        && hasElapsed(DeviceList.firstRequestDelay, since: createTime, at: now)
    }

    /// Forgets that the product information arrived, so it's asked for
    /// again (`ClearProductInformationLoaded`).
    mutating func clearProductInformationLoaded() {
      hasProductInformation = false
      productRequestTime = 0
      productRequests = 0
    }
  }

  /// The number of addresses a device can hold (`N2kMaxBusDevices`).
  static let addressCount = 254

  /// How long a device must be known before the list asks it anything
  /// (`N2kDL_TimeForFirstRequest`).
  static let firstRequestDelay: UInt32 = 1000

  /// How long to wait between repeats of a request
  /// (`N2kDL_TimeBetweenPIRequest`, `N2kDL_TimeBetweenCIRequest`).
  static let requestInterval: UInt32 = 1000

  /// How long a device must be silent before the list starts asking for its
  /// NAME again.
  static let nameRequestReset: UInt32 = 60000

  private var sources: [Device?] = Array(repeating: nil, count: addressCount)
  /// One past the highest address the list has used (`MaxDevices`).
  private var sourceLimit = 0
  private var hasPendingRequests = true

  /// Whether the list has changed since ``resetUpdated()`` was last called.
  public private(set) var isUpdated = false

  /// Creates an empty device list.
  public init() {}

  /// The devices, in address order.
  public var devices: [Device] { sources.compactMap { $0 } }

  /// The number of devices (`Count`).
  public var count: Int { sources.count { $0 != nil } }

  /// The device at an address, if any (`FindDeviceBySource`).
  public subscript(source source: UInt8) -> Device? {
    Int(source) < Self.addressCount ? sources[Int(source)] : nil
  }

  /// The device with a NAME, if any (`FindDeviceByName`).
  public func device(named name: DeviceName) -> Device? {
    sources[..<sourceLimit].lazy.compactMap { $0 }.first { $0.rawName == name.rawValue }
  }

  /// The first device with a manufacturer code and unique number, either of
  /// which may be `nil` to match any (`FindDeviceByIDs`).
  public func device(manufacturerCode: UInt16?, uniqueNumber: UInt32?) -> Device? {
    guard manufacturerCode != nil || uniqueNumber != nil else { return nil }
    return sources[..<sourceLimit].lazy.compactMap { $0 }.first {
      let name = DeviceName(rawValue: $0.rawName)
      return (manufacturerCode == nil || name.manufacturerCode == manufacturerCode)
        && (uniqueNumber == nil || name.uniqueNumber == uniqueNumber)
    }
  }

  /// The first device after an address with a manufacturer code and product
  /// code, or from the start if `source` is `nil` (`FindDeviceByProduct`).
  public func device(manufacturerCode: UInt16, productCode: UInt16, after source: UInt8? = nil)
    -> Device?
  {
    // From the start when there's no address after `source` (upstream).
    let start = source.map { Int($0) < sourceLimit ? Int($0) + 1 : 0 } ?? 0
    return sources[start..<sourceLimit].lazy.compactMap { $0 }.first {
      DeviceName(rawValue: $0.rawName).manufacturerCode == manufacturerCode
        && $0.productInformation?.productCode == productCode
    }
  }

  /// Returns whether the list has changed since the last call, and clears
  /// the flag (`ReadResetIsListUpdated`).
  public mutating func resetUpdated() -> Bool {
    defer { isUpdated = false }
    return isUpdated
  }

  /// Updates the list from a received message, sending requests as needed.
  ///
  /// - Parameters:
  ///   - message: A message received from the bus.
  ///   - time: The time it arrived, in milliseconds on a clock that may wrap.
  ///   - send: Sends a request, returning whether it could be sent. The
  ///     list only counts a request as made when it was sent.
  ///
  /// Ports `tN2kDeviceList::HandleMsg`.
  public mutating func handle(
    _ message: Message, at time: UInt32, sending send: (Message) -> Bool
  ) {
    let source = Int(message.source)
    guard source < Self.addressCount else { return }
    if sources[source] == nil {
      switch message.pgn {
      case ISOAddressClaim.pgn: break
      case ProductInformation.pgn, ConfigurationInformation.pgn, PGNList.pgn:
        addDevice(at: message.source, at: time, sending: send)
      default:
        addDevice(at: message.source, at: time, sending: send)
        return
      }
    }
    switch message.pgn {
    case ISOAddressClaim.pgn: handleAddressClaim(message, at: time, sending: send)
    case ProductInformation.pgn: handleProductInformation(message)
    case ConfigurationInformation.pgn: handleConfigurationInformation(message)
    case PGNList.pgn: handlePGNList(message)
    default: requestNextInformation(from: message.source, at: time, sending: send)
    }
    guard var device = sources[source] else { return }
    if device.rawName == 0 && device.nameRequests > 0
      && hasElapsed(Self.nameRequestReset, since: device.lastMessageTime, at: time)
    {
      device.nameRequests = 0
      hasPendingRequests = true
    }
    device.lastMessageTime = time
    sources[source] = device
  }

  // MARK: - Requests

  private static func request(_ pgn: UInt32, from source: UInt8) -> Message {
    ISORequest(requestedPGN: pgn).makeMessage(destination: source)
  }

  /// Asks a newly heard address for its NAME, and reserves the address if
  /// the request went out (`AddDevice`).
  private mutating func addDevice(
    at source: UInt8, at time: UInt32, sending send: (Message) -> Bool
  ) {
    guard send(Self.request(ISOAddressClaim.pgn, from: source)) else { return }
    save(Device(name: 0, source: source, at: time), at: source)
    hasPendingRequests = true
  }

  /// Makes the next request the list owes: the NAME of the device just
  /// heard, then product information, configuration information and PGN
  /// lists, one request at a time, in address order.
  ///
  /// Ports `tN2kDeviceList::HandleOther`.
  private mutating func requestNextInformation(
    from source: UInt8, at time: UInt32, sending send: (Message) -> Bool
  ) {
    guard hasPendingRequests else { return }
    hasPendingRequests = false
    if let device = sources[Int(source)], device.shouldRequestName,
      send(Self.request(ISOAddressClaim.pgn, from: source))
    {
      sources[Int(source)]?.nameRequests += 1
      hasPendingRequests = true
    }

    for index in 0..<sourceLimit {
      guard let device = sources[index] else { continue }
      if device.isReadyToRequestProductInformation(at: time) {
        if send(Self.request(ProductInformation.pgn, from: device.source)) {
          sources[index]?.productRequestTime = time
          sources[index]?.productRequests += 1
          hasPendingRequests = true
          return
        }
      } else if device.shouldRequestProductInformation {
        hasPendingRequests = true
      }
    }
    guard !hasPendingRequests else { return }

    for index in 0..<sourceLimit {
      guard let device = sources[index] else { continue }
      if device.isReadyToRequestConfigurationInformation(at: time) {
        if send(Self.request(ConfigurationInformation.pgn, from: device.source)) {
          sources[index]?.configurationRequestTime = time
          sources[index]?.configurationRequests += 1
          hasPendingRequests = true
          return
        }
      } else if device.shouldRequestConfigurationInformation {
        hasPendingRequests = true
      }
    }
    guard !hasPendingRequests else { return }

    for index in 0..<sourceLimit {
      guard let device = sources[index] else { continue }
      if device.isReadyToRequestPGNLists(at: time) {
        if send(Self.request(PGNList.pgn, from: device.source)) {
          sources[index]?.pgnListRequestTime = time
          sources[index]?.pgnListRequests += 1
          hasPendingRequests = true
          return
        }
      } else if device.shouldRequestPGNLists {
        hasPendingRequests = true
      }
    }
  }

  // MARK: - Information

  /// Puts a device at an address (`SaveDevice`).
  private mutating func save(_ device: Device, at source: UInt8) {
    var device = device
    device.source = source
    sources[Int(source)] = device
    sourceLimit = max(sourceLimit, Int(source) + 1)
  }

  /// Records a device's NAME at the address it claims, moving it if it has
  /// moved, and moving aside a different device that held the address.
  ///
  /// Ports `tN2kDeviceList::HandleIsoAddressClaim`.
  private mutating func handleAddressClaim(
    _ message: Message, at time: UInt32, sending send: (Message) -> Bool
  ) {
    let name = ISOAddressClaim(listMessage: message).name.rawValue
    let source = message.source
    var claimant: Device?
    if let existing = sources[Int(source)] {
      if existing.rawName == 0 {
        // The address was reserved when the device was first heard.
        guard name != 0 else { return }
        if let moved = device(named: DeviceName(rawValue: name)) {
          sources[Int(moved.source)] = nil
          save(moved, at: source)
          claimant = moved
        } else {
          sources[Int(source)]?.rawName = name
          isUpdated = true
          claimant = sources[Int(source)]
        }
      } else if existing.rawName != name {
        // Another device took the address: keep the old one at the first
        // free index, and ask everyone to claim again.
        if let free = sources.firstIndex(where: { $0 == nil }) {
          save(existing, at: UInt8(free))
          _ = send(Self.request(ISOAddressClaim.pgn, from: Message.broadcastAddress))
        }
        sources[Int(source)] = nil
      } else {
        return
      }
    }
    if claimant == nil {
      if name != 0, let moved = device(named: DeviceName(rawValue: name)) {
        sources[Int(moved.source)] = nil
        save(moved, at: source)
      } else {
        save(Device(name: name, source: source, at: time), at: source)
      }
    }
    sources[Int(source)]?.clearProductInformationLoaded()
    hasPendingRequests = true
    isUpdated = true
  }

  /// Ports `tN2kDeviceList::HandleProductInformation`.
  private mutating func handleProductInformation(_ message: Message) {
    guard let device = sources[Int(message.source)], !device.hasProductInformation,
      let product = try? ProductInformation(message)
    else { return }
    sources[Int(message.source)]?.hasProductInformation = true
    if device.productInformation != product {
      sources[Int(message.source)]?.productInformation = product
      isUpdated = true
    }
  }

  /// Ports `tN2kDeviceList::HandleConfigurationInformation`. A message
  /// whose strings don't parse is ignored, as upstream ignores it.
  private mutating func handleConfigurationInformation(_ message: Message) {
    guard sources[Int(message.source)] != nil else { return }
    var reader = MessageReader(message)
    guard let installation1 = reader.readVariableString(),
      let installation2 = reader.readVariableString(),
      let manufacturer = reader.readVariableString()
    else { return }
    sources[Int(message.source)]?.configurationInformation = ConfigurationInformation(
      manufacturerInformation: manufacturer, installationDescription1: installation1,
      installationDescription2: installation2)
    sources[Int(message.source)]?.hasConfigurationInformation = true
    isUpdated = true
  }

  /// Ports `tN2kDeviceList::HandleSupportedPGNList`.
  private mutating func handlePGNList(_ message: Message) {
    guard sources[Int(message.source)] != nil else { return }
    var reader = MessageReader(message)
    let kind = PGNList.Kind(rawValue: reader.readUInt8())
    let count = UInt8(truncatingIfNeeded: max(message.data.count - 1, 0) / 3)
    let pgns = (0..<count).map { _ in reader.readUInt24() }
    switch kind {
    case .transmit: sources[Int(message.source)]?.transmitPGNs = pgns
    case .receive: sources[Int(message.source)]?.receivePGNs = pgns
    default: break
    }
    isUpdated = true
  }
}

extension ISOAddressClaim {
  /// Decodes a claim the device list has already matched by PGN.
  fileprivate init(listMessage message: Message) {
    var reader = MessageReader(message)
    self.init(from: &reader)
  }
}
