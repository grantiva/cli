import Foundation

public struct JSONOutput: Sendable {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // ISO 8601, like --ready-file and the keep-alive session file; the
        // default is seconds since 2001, which scripts misread as Unix time.
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static func string<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// One sorted JSON document without whitespace, suitable for NDJSON streams.
    public static func compactString<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
