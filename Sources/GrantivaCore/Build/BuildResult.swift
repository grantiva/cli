import Foundation

public struct BuildResult: Sendable, Codable {
    public let success: Bool
    public let scheme: String?
    public let destination: String?
    public let duration: TimeInterval
    public let warnings: [String]
    public let errors: [String]
    public let productPath: String?
    public let applicationId: String?

    public init(
        success: Bool,
        scheme: String? = nil,
        destination: String? = nil,
        duration: TimeInterval,
        warnings: [String],
        errors: [String],
        productPath: String?,
        applicationId: String? = nil
    ) {
        self.success = success
        self.scheme = scheme
        self.destination = destination
        self.duration = duration
        self.warnings = warnings
        self.errors = errors
        self.productPath = productPath
        self.applicationId = applicationId
    }
}
