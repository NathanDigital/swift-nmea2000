// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

extension Node {
  /// Something that happened to the node, from ``Node/events(bufferingPolicy:)``.
  ///
  /// Replaces upstream's `SetOnOpen` callback and its `ReadResetAddressChanged`,
  /// `ReadResetDeviceInformationChanged` and
  /// `ReadResetInstallationDescriptionChanged` flags.
  public enum Event: Sendable, Hashable {
    /// The transport opened and the devices started claiming their
    /// addresses. Sending is possible once a claim ends, 250 ms later; see
    /// ``Node/waitUntilReady(_:)``.
    case opened
    /// A device's address claim ended with the address it now holds, so it
    /// can send.
    case addressClaimed(device: DeviceID, address: UInt8)
    /// A device found no free address, so it can't send.
    case addressClaimFailed(device: DeviceID)
    /// A device moved to another address. Save ``Node/devices`` so the
    /// device starts from it next time.
    case addressChanged(device: DeviceID)
    /// A device's NAME or heartbeat interval changed, from a clash with an
    /// identical device or another device's group function command.
    case deviceInformationChanged(device: DeviceID)
    /// Another device changed the installation descriptions in
    /// ``Node/configurationInformation`` with a group function command.
    case installationDescriptionChanged
    /// ``Node/deviceList`` changed: a device appeared, moved, or sent its
    /// details (upstream's `ReadResetIsListUpdated`).
    case deviceListChanged
  }
}
