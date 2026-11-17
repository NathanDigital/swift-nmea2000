// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 127233, man overboard notification.
///
/// Ports `SetN2kPGN127233` / `ParseN2kPGN127233`.
public struct ManOverboardNotification: ParameterGroup {
  public static let pgn: UInt32 = 127233
  public static let defaultPriority: UInt8 = 3

  /// The sequence identifier that ties together measurements taken at the same time, or `nil` if
  /// not available.
  public var sequenceID: UInt8?

  /// The identifier of the MOB emitter, or `nil` if not available.
  public var emitterID: UInt32?

  /// The state of the notification.
  public var status: MOBStatus

  /// The time the emitter was activated, in seconds since midnight UTC, or `nil` if not available.
  public var activationTime: Double?

  /// The source of the position.
  public var positionSource: MOBPositionSource

  /// The date of the position, in days since 1970-01-01, or `nil` if not available.
  public var positionDate: UInt16?

  /// The time of the position, in seconds since midnight UTC, or `nil` if not available.
  public var positionTime: Double?

  /// The latitude, in degrees, positive north, or `nil` if not available.
  public var latitude: Double?

  /// The longitude, in degrees, positive east, or `nil` if not available.
  public var longitude: Double?

  /// Whether the course over ground is true or magnetic.
  public var courseReference: HeadingReference

  /// The course over ground, in radians, or `nil` if not available.
  public var courseOverGround: Double?

  /// The speed over ground, in meters per second, or `nil` if not available.
  public var speedOverGround: Double?

  /// The MMSI of the vessel the emitter belongs to, or `nil` if not available.
  public var mmsi: UInt32?

  /// The battery status of the emitter.
  public var emitterBatteryStatus: MOBEmitterBatteryStatus

  /// Creates a man overboard notification message.
  public init(
    sequenceID: UInt8?,
    emitterID: UInt32?,
    status: MOBStatus,
    activationTime: Double?,
    positionSource: MOBPositionSource,
    positionDate: UInt16?,
    positionTime: Double?,
    latitude: Double?,
    longitude: Double?,
    courseReference: HeadingReference,
    courseOverGround: Double?,
    speedOverGround: Double?,
    mmsi: UInt32?,
    emitterBatteryStatus: MOBEmitterBatteryStatus
  ) {
    self.sequenceID = sequenceID
    self.emitterID = emitterID
    self.status = status
    self.activationTime = activationTime
    self.positionSource = positionSource
    self.positionDate = positionDate
    self.positionTime = positionTime
    self.latitude = latitude
    self.longitude = longitude
    self.courseReference = courseReference
    self.courseOverGround = courseOverGround
    self.speedOverGround = speedOverGround
    self.mmsi = mmsi
    self.emitterBatteryStatus = emitterBatteryStatus
  }

  public init(decoding reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    emitterID = reader.readOptionalUInt32()
    status = MOBStatus(rawValue: reader.readUInt8() & 0x07)
    activationTime = reader.readUInt32(resolution: 0.0001)
    positionSource = MOBPositionSource(rawValue: reader.readUInt8() & 0x07)
    positionDate = reader.readOptionalUInt16()
    positionTime = reader.readUInt32(resolution: 0.0001)
    latitude = reader.readInt32(resolution: 1e-7)
    longitude = reader.readInt32(resolution: 1e-7)
    courseReference = HeadingReference(rawValue: reader.readUInt8() & 0x03)
    courseOverGround = reader.readUInt16(resolution: 0.0001)
    speedOverGround = reader.readUInt16(resolution: 0.01)
    mmsi = reader.readOptionalUInt32()
    emitterBatteryStatus = MOBEmitterBatteryStatus(rawValue: reader.readUInt8() & 0x07)
  }

  public func encode(into writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt32(emitterID)
    writer.appendUInt8(status.rawValue & 0x07 | 0xf8)
    writer.appendUInt32(activationTime, resolution: 0.0001)
    writer.appendUInt8(positionSource.rawValue & 0x07 | 0xf8)
    writer.appendUInt16(positionDate)
    writer.appendUInt32(positionTime, resolution: 0.0001)
    writer.appendInt32(latitude, resolution: 1e-7)
    writer.appendInt32(longitude, resolution: 1e-7)
    writer.appendUInt8(courseReference.rawValue & 0x03 | 0xfc)
    writer.appendUInt16(courseOverGround, resolution: 0.0001)
    writer.appendUInt16(speedOverGround, resolution: 0.01)
    writer.appendUInt32(mmsi)
    writer.appendUInt8(emitterBatteryStatus.rawValue & 0x07 | 0xf8)
  }
}
