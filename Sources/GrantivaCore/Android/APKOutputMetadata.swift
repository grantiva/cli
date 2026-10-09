import Foundation

/// The Android Gradle Plugin writes one of these next to each variant's APKs
/// under `<module>/build/outputs/apk/`. It is the source of the application
/// ID and of which APK fits the target device.
public struct APKOutputMetadata: Decodable, Sendable, Equatable {
    public struct Filter: Decodable, Sendable, Equatable {
        public let filterType: String
        public let value: String
    }

    public struct Element: Decodable, Sendable, Equatable {
        public let type: String
        public let filters: [Filter]
        public let outputFile: String

        var abi: String? { filters.first(where: { $0.filterType == "ABI" })?.value }
    }

    public struct Located: Sendable, Equatable {
        public let metadata: APKOutputMetadata
        public let directory: String
    }

    public let applicationId: String
    public let variantName: String
    public let elements: [Element]

    public static let fileName = "output-metadata.json"

    /// Walks `<buildDirectory>/outputs/apk` for the metadata of `variant`.
    public static func find(buildDirectory: String, variant: String, fileManager: FileManager = .default) throws -> Located? {
        let apkRoot = "\(buildDirectory)/outputs/apk"
        guard let enumerator = fileManager.enumerator(atPath: apkRoot) else { return nil }
        for case let relative as String in enumerator where relative.hasSuffix(fileName) {
            let path = "\(apkRoot)/\(relative)"
            guard let data = fileManager.contents(atPath: path) else { continue }
            let metadata: APKOutputMetadata
            do {
                metadata = try JSONDecoder().decode(APKOutputMetadata.self, from: data)
            } catch {
                throw GrantivaError.buildFailed("\(path) could not be parsed: \(error)")
            }
            if metadata.variantName == variant {
                return Located(metadata: metadata, directory: (path as NSString).deletingLastPathComponent)
            }
        }
        return nil
    }

    /// The universal or single output when there is one, else the element
    /// whose ABI filter matches the device.
    public func apkPath(in directory: String, deviceABI: String) throws -> String {
        if let universal = elements.first(where: { $0.abi == nil }) {
            return "\(directory)/\(universal.outputFile)"
        }
        if let match = elements.first(where: { $0.abi == deviceABI }) {
            return "\(directory)/\(match.outputFile)"
        }
        let present = elements.compactMap(\.abi).sorted().joined(separator: ", ")
        throw GrantivaError.buildFailed(
            "No APK for the device ABI \(deviceABI); the build produced ABI splits for \(present). "
                + "Add a universal APK (splits.abi.universalApk true) or build for the device's ABI."
        )
    }
}
