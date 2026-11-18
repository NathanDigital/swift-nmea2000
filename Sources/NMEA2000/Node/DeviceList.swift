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
/// A ``Node`` keeps one when its configuration sets
/// ``Node/Configuration/discoversDevices``, and reports each change with
/// ``Node/Event/deviceListChanged``. To drive one yourself, pass it every
/// received message with ``handle(_:at:sending:)``.
///
/// Ports `tN2kDeviceList`.
public struct DeviceList: Sendable {
  /// A device on the bus.
  ///
  /// Two entries are equal when everything they report about the device is
  /// equal; the list's own record of what it has asked the device doesn't
  /// count.
  public struct Entry: Sendable, Hashable {
    /// The device's address.
    public fileprivate(set) var address: UInt8

    /// The device's NAME, or `nil` until it has claimed its address.
    public var name: DeviceName? { rawName == 0 ? nil : DeviceName(rawValue: rawName) }

    /// The device's product information, or `nil` until it has sent it.
    public fileprivate(set) var productInformation: ProductInformation?

    /// The device's configuration information, or `nil` until it has sent
    /// it.
    public fileprivate(set) var configurationInformation: ConfigurationInformation?

    /// The PGNs the device transmits, or `nil` until it has sent the list.
    public fileprivate(set) var transmitPGNs: [UInt32]?

    /// The PGNs the device receives, or `nil` until it has sent the list.
    public fileprivate(set) var receivePGNs: [UInt32]?

    /// When the device last sent a message, in the time passed to
    /// ``DeviceList/handle(_:at:sending:)``.
    public fileprivate(set) var lastMessageTime: Duration = .zero

    fileprivate var rawName: UInt64
    fileprivate let createTime: UInt32
    fileprivate var hasProductInformation = false
    fileprivate var hasConfigurationInformation = false
    fileprivate var nameRequests: UInt8 = 0
    fileprivate var productRequestTime: UInt32 = 0
    fileprivate var productRequests: UInt8 = 0
    fileprivate var configurationRequestTime: UInt32 = 0
    fileprivate var configurationRequests: UInt8 = 0
    fileprivate var pgnListRequestTime: UInt32 = 0
    fileprivate var pgnListRequests: UInt8 = 0

    init(name: UInt64, address: UInt8, at time: UInt32) {
      rawName = name
      self.address = address
      createTime = time
    }

    fileprivate var shouldRequestName: Bool { rawName == 0 && nameRequests < 20 }

    fileprivate var shouldRequestProductInformation: Bool {
      !hasProductInformation && productRequests < 4
    }

    fileprivate func isReadyToRequestProductInformation(at now: UInt32) -> Bool {
      shouldRequestProductInformation
        && hasElapsed(DeviceList.requestInterval, since: productRequestTime, at: now)
        && hasElapsed(DeviceList.firstRequestDelay, since: createTime, at: now)
    }

    fileprivate var shouldRequestConfigurationInformation: Bool {
      !hasConfigurationInformation && configurationRequests < 4
    }

    /// Upstream tests these intervals with `>` rather than `N2kHasElapsed`.
    fileprivate func isReadyToRequestConfigurationInformation(at now: UInt32) -> Bool {
      shouldRequestConfigurationInformation
        && now &- configurationRequestTime > DeviceList.requestInterval
        && now &- createTime > DeviceList.firstRequestDelay
    }

    fileprivate var shouldRequestPGNLists: Bool {
      (transmitPGNs == nil || receivePGNs == nil) && pgnListRequests < 4
    }

    fileprivate func isReadyToRequestPGNLists(at now: UInt32) -> Bool {
      shouldRequestPGNLists
        && hasElapsed(DeviceList.requestInterval, since: pgnListRequestTime, at: now)
        && hasElapsed(DeviceList.firstRequestDelay, since: createTime, at: now)
    }

    /// Forgets that the product information arrived, so it's asked for
    /// again (`ClearProductInformationLoaded`).
    fileprivate mutating func clearProductInformationLoaded() {
      hasProductInformation = false
      productRequestTime = 0
      productRequests = 0
    }

    public static func == (lhs: Entry, rhs: Entry) -> Bool {
      lhs.address == rhs.address && lhs.rawName == rhs.rawName
        && lhs.productInformation == rhs.productInformation
        && lhs.configurationInformation == rhs.configurationInformation
        && lhs.transmitPGNs == rhs.transmitPGNs && lhs.receivePGNs == rhs.receivePGNs
        && lhs.lastMessageTime == rhs.lastMessageTime
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(address)
      hasher.combine(rawName)
      hasher.combine(productInformation)
      hasher.combine(configurationInformation)
      hasher.combine(transmitPGNs)
      hasher.combine(receivePGNs)
      hasher.combine(lastMessageTime)
    }
  }

  /// The number of addresses a device can hold (`N2kMaxBusDevices`).
  private static let addressCount = 254

  /// How long a device must be known before the list asks it anything
  /// (`N2kDL_TimeForFirstRequest`).
  private static let firstRequestDelay: UInt32 = 1000

  /// How long to wait between repeats of a request
  /// (`N2kDL_TimeBetweenPIRequest`, `N2kDL_TimeBetweenCIRequest`).
  private static let requestInterval: UInt32 = 1000

  /// How long a device must be silent before the list starts asking for its
  /// NAME again.
  private static let nameRequestReset: UInt32 = 60000

  private var sources: [Entry?] = Array(repeating: nil, count: addressCount)
  /// One past the highest address the list has used (`MaxDevices`).
  private var sourceLimit = 0
  private var hasPendingRequests = true

  /// Whether the message being handled changed the list.
  private var isUpdated = false

  /// Creates an empty device list.
  public init() {}

  /// The devices, in address order.
  ///
  /// - Complexity: O(*n*), where *n* is the number of bus addresses (254).
  public var devices: [Entry] { sources.compactMap { $0 } }

  /// The number of devices (`Count`).
  ///
  /// - Complexity: O(*n*), where *n* is the number of bus addresses (254).
  public var count: Int { sources.count { $0 != nil } }

  /// The device at an address, if any (`FindDeviceBySource`).
  public subscript(address address: UInt8) -> Entry? {
    Int(address) < Self.addressCount ? sources[Int(address)] : nil
  }

  /// The device with a NAME, if any (`FindDeviceByName`).
  public func device(named name: DeviceName) -> Entry? {
    sources[..<sourceLimit].lazy.compactMap { $0 }.first { $0.rawName == name.rawValue }
  }

  /// The first device with a manufacturer code and unique number, either of
  /// which may be `nil` to match any (`FindDeviceByIDs`).
  public func device(manufacturerCode: UInt16?, uniqueNumber: UInt32?) -> Entry? {
    guard manufacturerCode != nil || uniqueNumber != nil else { return nil }
    return sources[..<sourceLimit].lazy.compactMap { $0 }.first {
      let name = DeviceName(rawValue: $0.rawName)
      return (manufacturerCode == nil || name.manufacturerCode == manufacturerCode)
        && (uniqueNumber == nil || name.uniqueNumber == uniqueNumber)
    }
  }

  /// The first device after an address with a manufacturer code and product
  /// code, or from the start if `address` is `nil` (`FindDeviceByProduct`).
  public func device(manufacturerCode: UInt16, productCode: UInt16, after address: UInt8? = nil)
    -> Entry?
  {
    // From the start when there's no address after `address` (upstream).
    let start = address.map { Int($0) < sourceLimit ? Int($0) + 1 : 0 } ?? 0
    return sources[start..<sourceLimit].lazy.compactMap { $0 }.first {
      DeviceName(rawValue: $0.rawName).manufacturerCode == manufacturerCode
        && $0.productInformation?.productCode == productCode
    }
  }

  /// Updates the list from a received message, sending requests as needed.
  ///
  /// - Parameters:
  ///   - message: A message received from the bus.
  ///   - time: The time it arrived, since any fixed moment.
  ///   - send: Sends a request, returning whether it could be sent. The
  ///     list only counts a request as made when it was sent.
  /// - Returns: Whether the message changed the list, which upstream's
  ///   `ReadResetIsListUpdated` reports.
  ///
  /// Ports `tN2kDeviceList::HandleMsg`.
  @discardableResult
  public mutating func handle(
    _ message: Message, at time: Duration, sending send: (Message) -> Bool
  ) -> Bool {
    isUpdated = false
    handleMessage(message, at: time.wrappingMilliseconds, stamp: time, sending: send)
    return isUpdated
  }

  private mutating func handleMessage(
    _ message: Message, at time: UInt32, stamp: Duration, sending send: (Message) -> Bool
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
      && hasElapsed(
        Self.nameRequestReset, since: device.lastMessageTime.wrappingMilliseconds, at: time)
    {
      device.nameRequests = 0
      hasPendingRequests = true
    }
    device.lastMessageTime = stamp
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
    save(Entry(name: 0, address: source, at: time), at: source)
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
        if send(Self.request(ProductInformation.pgn, from: device.address)) {
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
        if send(Self.request(ConfigurationInformation.pgn, from: device.address)) {
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
        if send(Self.request(PGNList.pgn, from: device.address)) {
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
  private mutating func save(_ device: Entry, at source: UInt8) {
    var device = device
    device.address = source
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
    var claimant: Entry?
    if let existing = sources[Int(source)] {
      if existing.rawName == 0 {
        // The address was reserved when the device was first heard.
        guard name != 0 else { return }
        if let moved = device(named: DeviceName(rawValue: name)) {
          sources[Int(moved.address)] = nil
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
        sources[Int(moved.address)] = nil
        save(moved, at: source)
      } else {
        save(Entry(name: name, address: source, at: time), at: source)
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
    self.init(decoding: &reader)
  }
}
