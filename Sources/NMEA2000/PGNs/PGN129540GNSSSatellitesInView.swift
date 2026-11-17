// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// PGN 129540, GNSS satellites in view.
///
/// Ports `SetN2kPGN129540`, `AppendN2kPGN129540` and both
/// `ParseN2kPGN129540` overloads. Upstream builds the list one satellite at a
/// time; this type holds the whole list.
public struct GNSSSatellitesInView: ParameterGroup, Hashable {
  public static let pgn: UInt32 = 129540
  public static let defaultPriority: UInt8 = 6

  /// The most satellites one message can hold, as upstream limits it.
  public static let maxSatelliteCount = 18

  /// One satellite in view.
  ///
  /// Ports upstream's `tSatelliteInfo`.
  public struct Satellite: Sendable, Hashable {
    /// The satellite's PRN number, or `nil` if not available.
    public var prn: UInt8?

    /// The elevation, in radians, or `nil` if not available.
    public var elevation: Double?

    /// The azimuth, in radians, or `nil` if not available.
    public var azimuth: Double?

    /// The signal-to-noise ratio, in decibels, or `nil` if not available.
    public var signalToNoiseRatio: Double?

    /// The range residual, in meters, or `nil` if not available.
    public var rangeResiduals: Double?

    /// How the satellite is used in the solution.
    public var usageStatus: PRNUsageStatus

    /// Creates a satellite entry.
    public init(
      prn: UInt8?,
      elevation: Double?,
      azimuth: Double?,
      signalToNoiseRatio: Double?,
      rangeResiduals: Double?,
      usageStatus: PRNUsageStatus
    ) {
      self.prn = prn
      self.elevation = elevation
      self.azimuth = azimuth
      self.signalToNoiseRatio = signalToNoiseRatio
      self.rangeResiduals = rangeResiduals
      self.usageStatus = usageStatus
    }
  }

  /// The sequence identifier that ties together measurements taken at the same
  /// time, or `nil` if not available.
  public var sequenceID: UInt8?

  /// When the range residuals were calculated.
  public var mode: RangeResidualMode

  /// The satellites in view. Only the first ``maxSatelliteCount`` are sent.
  public var satellites: [Satellite]

  /// Creates a GNSS satellites in view message.
  ///
  /// The defaults match upstream's `SetN2kPGN129540`.
  public init(
    sequenceID: UInt8? = nil, mode: RangeResidualMode = .unavailable, satellites: [Satellite] = []
  ) {
    self.sequenceID = sequenceID
    self.mode = mode
    self.satellites = satellites
  }

  /// Decodes the fields from a payload.
  ///
  /// Every satellite the message declares is decoded. Upstream's
  /// per-satellite parser refuses all of them when more than
  /// ``maxSatelliteCount`` are declared, which a message sent by transport
  /// protocol can hold.
  public init(from reader: inout MessageReader) {
    sequenceID = reader.readOptionalUInt8()
    mode = RangeResidualMode(rawValue: reader.readUInt8() & 0x03)
    // A payload that ends before the count holds no satellites.
    let count = reader.remainingCount > 0 ? Int(reader.readUInt8()) : 0
    satellites = (0..<count).map { _ in
      Satellite(
        prn: reader.readOptionalUInt8(),
        elevation: reader.readInt16(resolution: 1e-4),
        azimuth: reader.readUInt16(resolution: 1e-4),
        signalToNoiseRatio: reader.readInt16(resolution: 1e-2),
        rangeResiduals: reader.readInt32(resolution: 1e-5),
        usageStatus: PRNUsageStatus(rawValue: reader.readUInt8() & 0x0f))
    }
  }

  public func encode(to writer: inout MessageWriter) {
    writer.appendUInt8(sequenceID)
    writer.appendUInt8(0xfc | mode.rawValue & 0x03)
    let sent = satellites.prefix(Self.maxSatelliteCount)
    writer.appendUInt8(UInt8(sent.count))
    for satellite in sent {
      writer.appendUInt8(satellite.prn)
      writer.appendInt16(satellite.elevation, resolution: 1e-4)
      writer.appendUInt16(satellite.azimuth, resolution: 1e-4)
      writer.appendInt16(satellite.signalToNoiseRatio, resolution: 1e-2)
      writer.appendInt32(satellite.rangeResiduals, resolution: 1e-5)
      writer.appendUInt8(0xf0 | satellite.usageStatus.rawValue)
    }
  }
}
