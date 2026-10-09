import Foundation
import GrantivaCore

/// Filled in by the emulator tools (next task). Declared here so the registry
/// can carry it.
struct EmulatorToolDependencies: Sendable {
    static func live() throws -> EmulatorToolDependencies { EmulatorToolDependencies() }
}
