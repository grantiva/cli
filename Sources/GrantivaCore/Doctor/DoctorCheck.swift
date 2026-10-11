import Foundation

public struct DoctorCheck: Sendable, Codable {
    public let name: String
    public let status: Status
    public let message: String
    public let fix: String?
    public let section: Section

    public enum Status: String, Sendable, Codable, CaseIterable {
        case ok
        case warning
        case error
    }

    public enum Section: String, Sendable, Codable {
        case required = "Required"
        /// Checks that can never fail doctor: device state (a booted
        /// simulator, AVDs, a running emulator), the runner install (extracted
        /// on first use) and, when no single platform is detected, the
        /// toolchains doctor inspects only as advice.
        case advisory = "Advisory"
        case project = "Project"
        case cloud = "CI / Cloud"
    }

    public init(name: String, status: Status, message: String, fix: String?, section: Section = .required) {
        self.name = name
        self.status = status
        self.message = message
        self.fix = fix
        self.section = section
    }

    /// The same check reported under another heading.
    public func inSection(_ section: Section) -> DoctorCheck {
        DoctorCheck(name: name, status: status, message: message, fix: fix, section: section)
    }
}
