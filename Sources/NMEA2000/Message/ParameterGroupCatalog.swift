// swift-nmea2000: a Swift port of Timo Lappalainen's NMEA2000 library.
// https://github.com/ttlappalainen/NMEA2000
//
// Copyright (c) 2026 NathanDigital. Original work Copyright (c) 2015-2026
// Timo Lappalainen, Kave Oy. Licensed under the MIT License; see LICENSE.

/// Parameter group types by PGN, for decoding received messages without
/// switching on their PGNs.
///
/// ```swift
/// for await message in await node.messages() {
///   switch try? message.decoded() {
///   case let position as PositionRapidUpdate: show(position)
///   case let wind as WindData: show(wind)
///   default: break
///   }
/// }
/// ```
///
/// To receive one type only,
/// ``Node/messages(of:includingSent:bufferingPolicy:)`` is simpler.
public struct ParameterGroupCatalog: Sendable {
  private var types: [UInt32: any ParameterGroup.Type]

  /// The PGNs the catalog has a type for.
  public var pgns: Set<UInt32> { Set(types.keys) }

  /// The type for a PGN, if the catalog has one.
  public subscript(pgn pgn: UInt32) -> (any ParameterGroup.Type)? { types[pgn] }

  /// Creates a catalog of types. Of types with the same PGN, the last
  /// counts.
  public init(_ types: [any ParameterGroup.Type]) {
    self.types = [:]
    add(types)
  }

  /// Adds types, replacing any with the same PGN.
  public mutating func add(_ types: [any ParameterGroup.Type]) {
    for type in types { self.types[type.pgn] = type }
  }

  /// Adds another catalog's types, replacing any with the same PGN.
  public mutating func add(_ catalog: ParameterGroupCatalog) {
    types.merge(catalog.types) { _, new in new }
  }

  /// Returns the catalog with another catalog's types added, replacing any
  /// with the same PGN.
  ///
  /// ```swift
  /// let catalog = ParameterGroupCatalog.standard.adding(.maretron)
  /// ```
  public func adding(_ catalog: ParameterGroupCatalog) -> ParameterGroupCatalog {
    var result = self
    result.add(catalog)
    return result
  }

  /// Decodes a message with the type for its PGN, or returns `nil` if the
  /// catalog has none.
  ///
  /// - Throws: An error from the type if it can't decode the message; the
  ///   types in this library throw ``MessageDecodingError``.
  public func decode(_ message: Message) throws -> (any ParameterGroup)? {
    guard let type = types[message.pgn] else { return nil }
    return try type.init(message)
  }
}
