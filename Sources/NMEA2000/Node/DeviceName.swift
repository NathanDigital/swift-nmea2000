// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// The 64-bit NAME a device claims its bus address with, which identifies it
/// on the bus and decides address conflicts: the lower NAME keeps the address.
///
/// The fields are packed little-endian, from the lowest bits up: unique
/// number (21 bits), manufacturer code (11 bits), device instance (8 bits),
/// device function (8 bits), a reserved bit, device class (7 bits), system
/// instance (4 bits), industry group (3 bits) and the arbitrary address
/// capable bit. Setting a field masks the value to its width, as upstream
/// does.
///
/// Ports `tNMEA2000::tDeviceInformation`.
public struct DeviceName: RawRepresentable, Sendable, Hashable, Comparable {
  /// The NAME as it is sent on the bus.
  public var rawValue: UInt64

  /// Creates a NAME from its 64-bit value.
  public init(rawValue: UInt64) {
    self.rawValue = rawValue
  }

  /// Creates a NAME from its fields, with the arbitrary address capable bit
  /// set.
  ///
  /// Ports the field form of `SetN2kPGN60928`.
  ///
  /// - Parameters:
  ///   - uniqueNumber: The number that tells apart devices of the same model
  ///     from one manufacturer, such as a serial number (21 bits).
  ///   - manufacturerCode: The manufacturer's registered code (11 bits).
  ///   - deviceFunction: The device function code, whose meaning depends on
  ///     the device class.
  ///   - deviceClass: The device class code (7 bits).
  ///   - deviceInstance: The device instance.
  ///   - systemInstance: The system instance (4 bits).
  ///   - industryGroup: The industry group (3 bits). 4 is marine.
  public init(
    uniqueNumber: UInt32,
    manufacturerCode: UInt16,
    deviceFunction: UInt8,
    deviceClass: UInt8,
    deviceInstance: UInt8 = 0,
    systemInstance: UInt8 = 0,
    industryGroup: UInt8 = 4
  ) {
    rawValue = 0
    self.uniqueNumber = uniqueNumber
    self.manufacturerCode = manufacturerCode
    self.deviceInstance = deviceInstance
    self.deviceFunction = deviceFunction
    self.deviceClass = deviceClass
    self.systemInstance = systemInstance
    self.industryGroup = industryGroup
  }

  /// The NAME upstream gives a device that doesn't set its own: unique
  /// number 1, manufacturer code 2046, device function 130 (PC gateway),
  /// device class 25 (inter/intranetwork device) and industry group 4
  /// (marine).
  ///
  /// Set a NAME of your own before connecting to a real bus: devices with
  /// the same NAME fight over addresses.
  public static let `default` = DeviceName(
    uniqueNumber: 1, manufacturerCode: 2046, deviceFunction: 130, deviceClass: 25)

  /// The number that tells apart devices of the same model from one
  /// manufacturer (21 bits).
  public var uniqueNumber: UInt32 {
    get { UInt32(field(at: 0, width: 21)) }
    set { setField(UInt64(newValue), at: 0, width: 21) }
  }

  /// The manufacturer's registered code (11 bits).
  public var manufacturerCode: UInt16 {
    get { UInt16(field(at: 21, width: 11)) }
    set { setField(UInt64(newValue), at: 21, width: 11) }
  }

  /// The device instance, which tells apart devices of the same kind on one
  /// bus.
  public var deviceInstance: UInt8 {
    get { UInt8(field(at: 32, width: 8)) }
    set { setField(UInt64(newValue), at: 32, width: 8) }
  }

  /// The lower three bits of the device instance.
  public var deviceInstanceLower: UInt8 {
    get { UInt8(field(at: 32, width: 3)) }
    set { setField(UInt64(newValue), at: 32, width: 3) }
  }

  /// The upper five bits of the device instance.
  public var deviceInstanceUpper: UInt8 {
    get { UInt8(field(at: 35, width: 5)) }
    set { setField(UInt64(newValue), at: 35, width: 5) }
  }

  /// The device function code, whose meaning depends on the device class.
  public var deviceFunction: UInt8 {
    get { UInt8(field(at: 40, width: 8)) }
    set { setField(UInt64(newValue), at: 40, width: 8) }
  }

  /// The device class code (7 bits).
  public var deviceClass: UInt8 {
    get { UInt8(field(at: 49, width: 7)) }
    set { setField(UInt64(newValue), at: 49, width: 7) }
  }

  /// The system instance, which tells apart separate networks (4 bits).
  public var systemInstance: UInt8 {
    get { UInt8(field(at: 56, width: 4)) }
    set { setField(UInt64(newValue), at: 56, width: 4) }
  }

  /// The industry group (3 bits). 4 is marine.
  ///
  /// Setting it also sets ``isArbitraryAddressCapable``, as upstream does.
  public var industryGroup: UInt8 {
    get { UInt8(field(at: 60, width: 3)) }
    set {
      setField(UInt64(newValue), at: 60, width: 3)
      isArbitraryAddressCapable = true
    }
  }

  /// Whether the device can pick another address when it loses an address
  /// conflict.
  public var isArbitraryAddressCapable: Bool {
    get { field(at: 63, width: 1) != 0 }
    set { setField(newValue ? 1 : 0, at: 63, width: 1) }
  }

  public static func < (lhs: DeviceName, rhs: DeviceName) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  private func field(at offset: Int, width: Int) -> UInt64 {
    rawValue >> offset & (1 << width - 1)
  }

  private mutating func setField(_ value: UInt64, at offset: Int, width: Int) {
    let mask: UInt64 = (1 << width - 1) << offset
    rawValue = rawValue & ~mask | value << offset & mask
  }
}
