import Foundation

/// The keys a `--json` document still writes in both spellings.
///
/// Every `--json` document uses camelCase keys. A few documents used
/// snake_case before that rule; for one deprecation period they write each of
/// those values under the camelCase key and, beside it, under the old
/// snake_case key. `renamed` is the single table: the encoders look the alias
/// up here, the key-casing test allows exactly these, and the README lists
/// them.
public struct LegacyJSONKeys: CodingKey, ExpressibleByStringLiteral {
    public let stringValue: String
    public var intValue: Int? { nil }
    public init(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue: Int) { nil }
    public init(stringLiteral value: String) { self.stringValue = value }

    /// camelCase key → the snake_case key still written beside it, with the
    /// commands whose documents carry it.
    public static let renamed: [(camel: String, snake: String, commands: String)] = [
        ("screenName", "screen_name", "diff capture, diff compare"),
        ("sizeBytes", "size_bytes", "diff capture"),
        ("pointDimensions", "point_dimensions", "diff capture, simulator ensure"),
        ("pixelDimensions", "pixel_dimensions", "diff capture, simulator ensure"),
        ("displayScale", "display_scale", "diff capture, simulator ensure"),
        ("deviceType", "device_type", "simulator ensure"),
        ("pixelDiffPercent", "pixel_diff_percent", "diff compare"),
        ("perceptualDistance", "perceptual_distance", "diff compare"),
        ("pixelThreshold", "pixel_threshold", "diff compare"),
        ("perceptualThreshold", "perceptual_threshold", "diff compare"),
        ("baselinePath", "baseline_path", "diff compare"),
        ("capturePath", "capture_path", "diff compare"),
        ("diffImagePath", "diff_image_path", "diff compare"),
        ("approvedScreens", "approved_screens", "diff approve"),
        ("baselineDirectory", "baseline_directory", "diff approve"),
    ]

    /// snake_case alias → its camelCase key.
    public static let aliases: [String: String] = Dictionary(uniqueKeysWithValues: renamed.map { ($0.snake, $0.camel) })

    /// camelCase key → its snake_case alias.
    static let aliasOf: [String: String] = Dictionary(uniqueKeysWithValues: renamed.map { ($0.camel, $0.snake) })
}

extension KeyedEncodingContainer where K == LegacyJSONKeys {
    /// Writes `value` under `key` and, when `LegacyJSONKeys.renamed` lists
    /// one, under its snake_case alias too.
    public mutating func encodeWithAlias<T: Encodable>(_ value: T, _ key: String) throws {
        try encode(value, forKey: LegacyJSONKeys(stringValue: key))
        if let alias = LegacyJSONKeys.aliasOf[key] {
            try encode(value, forKey: LegacyJSONKeys(stringValue: alias))
        }
    }

    /// `encodeWithAlias` for an optional, omitting both keys when nil.
    public mutating func encodeIfPresentWithAlias<T: Encodable>(_ value: T?, _ key: String) throws {
        guard let value else { return }
        try encodeWithAlias(value, key)
    }
}
