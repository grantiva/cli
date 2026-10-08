import Foundation

public enum Platform: String, Sendable, Codable, CaseIterable {
    case ios
    case android

    public var configFileName: String {
        switch self {
        case .ios: return "grantiva.yml"
        case .android: return "grantiva-android.yml"
        }
    }

    public var displayName: String {
        switch self {
        case .ios: return "iOS"
        case .android: return "Android"
        }
    }
}
