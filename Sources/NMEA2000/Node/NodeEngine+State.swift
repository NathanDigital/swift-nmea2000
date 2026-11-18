// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

extension NodeEngine {
  enum OpenState: Hashable {
    /// The transport isn't open; try to open it at the given time.
    case closed(retryAt: UInt64)
    /// The transport is open; claim addresses at the given time.
    case waiting(until: UInt64)
    /// The node is running.
    case open
  }

  /// One device's state (upstream's `tInternalDevice`).
  struct DeviceState: Sendable {
    var address: UInt8
    var name: DeviceName
    /// `nil` to send the first device's.
    var productInformation: ProductInformation?
    var transmitPGNs: [UInt32]
    var receivePGNs: [UInt32]
    /// The heartbeat interval in milliseconds, or `nil` for none.
    var heartbeatInterval: UInt64?
    /// The device's fast-packet sequence counters.
    var framer: MessageFramer

    /// The last address to try before giving up, one before the address the
    /// device last held (upstream's `AddressClaimEndSource`).
    var lastAddressToTry: UInt8 = 0
    /// When the address claim in progress ends, or `nil` if there isn't one.
    var claimDeadline: UInt64?
    /// The message being sent by transport protocol, if any (upstream's
    /// `PendingTPMsg`).
    var transfer: Transfer?
    /// When heartbeats are due, once the node is open (upstream's
    /// `HeartbeatScheduler`).
    var heartbeat: HeartbeatSchedule?
    /// The heartbeat period and offset in milliseconds, kept while the
    /// heartbeat is off, as upstream's scheduler keeps them when disabled.
    var lastHeartbeatPeriod: UInt64
    var lastHeartbeatOffset = NodeEngine.heartbeatOffset
    /// The next heartbeat's sequence counter (upstream's
    /// `HeartbeatSequence`), which carries on when the heartbeat stops and
    /// starts again.
    var heartbeatSequence: UInt8 = 0
    /// When to send an address claim that was put off for a moment, if any
    /// (upstream's `PendingIsoAddressClaim`).
    var pendingClaim: UInt64?
    /// When to try again to send product information that couldn't be sent
    /// (upstream's `PendingProductInformation`).
    var pendingProductInformation: UInt64?
    /// When to try again to send configuration information that couldn't be
    /// sent (upstream's `PendingConfigurationInformation`).
    var pendingConfigurationInformation: UInt64?

    init(_ device: Node.Device, catalog: PGNCatalog) {
      address = device.address
      name = device.name
      productInformation = device.productInformation
      transmitPGNs = device.transmitPGNs
      receivePGNs = device.receivePGNs
      heartbeatInterval = device.heartbeatInterval.map {
        // Upstream keeps the interval between 1 and 655.32 seconds.
        min(max($0.wholeMilliseconds, 1000), 655_320)
      }
      lastHeartbeatPeriod = heartbeatInterval ?? NodeEngine.defaultHeartbeatInterval
      framer = MessageFramer(catalog: catalog, transmitPGNs: device.transmitPGNs)
      resetLastAddressToTry()
    }

    /// Ports `UpdateAddressClaimEndSource`.
    mutating func resetLastAddressToTry() {
      lastAddressToTry = address > 0 ? address - 1 : MessageFramer.maxBusAddress
    }

    /// The device's settings as they are now.
    var settings: Node.Device {
      Node.Device(
        address: address, name: name, productInformation: productInformation,
        transmitPGNs: transmitPGNs, receivePGNs: receivePGNs,
        heartbeatInterval: heartbeatInterval.map { .milliseconds($0) })
    }
  }

  /// A heartbeat schedule synchronised to the time the node opened
  /// (upstream's `tN2kSyncScheduler`).
  struct HeartbeatSchedule: Sendable {
    /// When the node opened.
    var sync: UInt64
    /// How long after opening the first heartbeat is due.
    var offset: UInt64
    var period: UInt64
    /// Heartbeats are sent once this time has passed.
    var next: UInt64 = 0

    init(sync: UInt64, offset: UInt64, period: UInt64, now: UInt64) {
      self.sync = sync
      self.offset = offset
      self.period = period
      scheduleNext(at: now)
    }

    /// Schedules the next heartbeat: the first one if it's still to come,
    /// otherwise the next whole period after it.
    ///
    /// Ports `tN2kSyncScheduler::UpdateNextTime`.
    mutating func scheduleNext(at now: UInt64) {
      let start = sync + offset
      next = start > now ? start : start + ((now - start) / period + 1) * period
    }
  }

  struct Transfer: Sendable {
    var message: Message
    /// How many data packets have been sent (`NextDTSequence`).
    var sentPackets = 0
    /// When to send the next broadcast packet, or give up waiting for a
    /// clear to send (`NextDTSendTime`).
    var deadline: UInt64

    var isBroadcast: Bool { message.destination == Message.broadcastAddress }
    var isComplete: Bool { sentPackets * 7 >= message.data.count }
  }
}
