// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

extension Node {
  /// How a node takes part in the bus.
  ///
  /// Upstream has five modes. Pairs of them differ only in whether messages
  /// are forwarded to a stream, which isn't part of this type, so they map
  /// onto three.
  public enum Mode: Sendable, Hashable {
    /// Receives messages and never sends any (upstream's `N2km_ListenOnly`).
    case listenOnly

    /// Receives and sends messages without claiming an address (upstream's
    /// `N2km_SendOnly` and `N2km_ListenAndSend`). The address must not be
    /// used by another device.
    case listenAndSend

    /// A full node: claims an address and defends it, answers ISO requests
    /// and group functions, and sends heartbeats (upstream's
    /// `N2km_NodeOnly` and `N2km_ListenAndNode`).
    case node
  }

  /// A device the node hosts on the bus.
  ///
  /// Most nodes host one device. A node can host several, as upstream's
  /// `SetDeviceCount` allows, each with its own address, NAME and
  /// heartbeat; they share the transport and the configuration
  /// information.
  public struct Device: Sendable, Hashable {
    /// The address to claim first. If another device holds it, the device
    /// tries the following addresses, skipping its sibling devices'. 254
    /// starts from 14. Save it when it changes and use it next time, so the
    /// device keeps its address across restarts.
    public var address: UInt8

    /// The NAME to claim the address with. Every device on a bus needs a
    /// different NAME.
    public var name: DeviceName

    /// The product information the device sends when asked, or `nil` for
    /// the first device's.
    public var productInformation: ProductInformation?

    /// The PGNs the device sends, beyond the network management PGNs every
    /// node sends. The device lists them when asked.
    public var transmitPGNs: [UInt32]

    /// The PGNs the device receives, beyond the network management PGNs.
    /// The device lists them when asked.
    public var receivePGNs: [UInt32]

    /// How often to send a heartbeat, between 1 and 655.32 seconds, or `nil`
    /// for none. The first is sent 10 seconds after the node opens.
    public var heartbeatInterval: Duration?

    /// Creates a device.
    ///
    /// - Parameters:
    ///   - address: The address to claim first.
    ///   - name: The NAME to claim the address with, which must differ from
    ///     every other device's on the bus.
    ///   - productInformation: The product information the device sends
    ///     when asked, or `nil` for the first device's, which needs its own.
    ///   - transmitPGNs: The PGNs the device sends.
    ///   - receivePGNs: The PGNs the device receives.
    ///   - heartbeatInterval: How often to send a heartbeat, or `nil` for
    ///     none.
    public init(
      address: UInt8 = 15,
      name: DeviceName,
      productInformation: ProductInformation?,
      transmitPGNs: [UInt32] = [],
      receivePGNs: [UInt32] = [],
      heartbeatInterval: Duration? = .seconds(60)
    ) {
      self.address = address
      self.name = name
      self.productInformation = productInformation
      self.transmitPGNs = transmitPGNs
      self.receivePGNs = receivePGNs
      self.heartbeatInterval = heartbeatInterval
    }
  }

  /// Identifies one of the devices a node hosts, by its position in the
  /// devices the node was created with. The first device is ``first``, or
  /// `0`.
  public struct DeviceID: RawRepresentable, Hashable, Sendable, Codable,
    ExpressibleByIntegerLiteral, CustomStringConvertible
  {
    /// The device's position in the node's devices.
    public var rawValue: Int

    /// Creates the identifier of the device at a position.
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    /// Creates the identifier of the device at a position.
    public init(integerLiteral value: Int) {
      self.init(rawValue: value)
    }

    /// The first device, which most nodes host alone.
    public static let first = DeviceID(rawValue: 0)

    public var description: String { "device \(rawValue)" }
  }

  /// How a node takes part in the bus, and the devices it hosts.
  ///
  /// Start from ``node(_:configurationInformation:)``,
  /// ``listenOnly`` or ``listenAndSend(address:)``, and change the other
  /// properties as needed.
  ///
  /// Replaces upstream's settings before `Open`: `SetMode`, `SetN2kSource`,
  /// `SetDeviceCount`, `SetDeviceInformation`, `SetProductInformation`,
  /// `SetConfigurationInformation`, `Extend…Messages`,
  /// `SetHandleOnlyKnownMessages` and `SetN2kCANMsgBufSize`.
  public struct Configuration: Sendable {
    /// How the node takes part in the bus. Set when the configuration is
    /// created, which checks it against the devices.
    public private(set) var mode: Mode

    /// The devices the node hosts, at least one. Most nodes host one. Set
    /// when the configuration is created, which checks them.
    public private(set) var devices: [Device]

    /// The configuration information the devices send when asked, or `nil`
    /// to refuse requests for it.
    public var configurationInformation: ConfigurationInformation?

    /// Which PGNs are sent and received as fast packets.
    public var catalog = PGNCatalog()

    /// Whether to drop received messages whose PGN isn't in the catalog.
    public var handlesOnlyKnownMessages = false

    /// How many fast packets and transport protocol sessions can be
    /// reassembled at once. Upstream defaults to 5 (`SetN2kCANMsgBufSize`).
    public var bufferCount = 5

    /// Whether to keep a ``DeviceList`` of the devices on the bus, asking
    /// them for their details as upstream's `tN2kDeviceList` does. The
    /// first device asks.
    public var discoversDevices = false

    /// Creates a configuration.
    ///
    /// - Precondition: `devices` isn't empty, and in ``Mode/node`` mode the
    ///   first device has product information.
    public init(
      mode: Mode, devices: [Device], configurationInformation: ConfigurationInformation? = nil
    ) {
      precondition(!devices.isEmpty, "A node hosts at least one device")
      precondition(
        mode != .node || devices[0].productInformation != nil,
        "A full node's first device needs product information")
      self.mode = mode
      self.devices = devices
      self.configurationInformation = configurationInformation
    }

    /// A full node hosting one device: it claims an address, answers
    /// requests and group functions, and sends heartbeats.
    ///
    /// - Parameters:
    ///   - device: The device, with its own NAME and product information.
    ///   - configurationInformation: The configuration information the
    ///     device sends when asked, or `nil` to refuse requests for it.
    public static func node(
      _ device: Device, configurationInformation: ConfigurationInformation? = nil
    ) -> Configuration {
      Configuration(
        mode: .node, devices: [device], configurationInformation: configurationInformation)
    }

    /// A node that only receives, such as a logger or display.
    public static var listenOnly: Configuration {
      Configuration(mode: .listenOnly, devices: [Device(name: .default, productInformation: nil)])
    }

    /// A node that receives, and sends from an address it doesn't claim,
    /// which no other device on the bus may use.
    public static func listenAndSend(address: UInt8) -> Configuration {
      Configuration(
        mode: .listenAndSend,
        devices: [Device(address: address, name: .default, productInformation: nil)])
    }
  }
}
