import Foundation

public struct DoctorFormatter: Sendable {
    private let color: Bool

    /// `color: nil` decides from the environment: escapes are emitted only when
    /// stdout is a terminal and `NO_COLOR` is unset. Redirected output —
    /// `grantiva doctor > log.txt`, a CI log, a pipe into grep — was carrying
    /// raw SGR sequences that no one was going to render.
    public init(color: Bool? = nil) {
        self.color = color ?? Self.terminalSupportsColor()
    }

    static func terminalSupportsColor() -> Bool {
        if ProcessInfo.processInfo.environment["NO_COLOR"] != nil { return false }
        return isatty(STDOUT_FILENO) == 1
    }

    private func paint(_ text: String, _ code: String) -> String {
        color ? "\u{001B}[\(code)m\(text)\u{001B}[0m" : text
    }

    public func format(_ checks: [DoctorCheck]) -> String {
        var lines: [String] = []

        lines.append("")
        lines.append("  Grantiva Doctor")
        lines.append("  " + String(repeating: "─", count: 50))

        let sections: [DoctorCheck.Section] = [.required, .project, .cloud]

        for section in sections {
            let sectionChecks = checks.filter { $0.section == section }
            guard !sectionChecks.isEmpty else { continue }

            lines.append("")
            lines.append("  \(section.rawValue)")
            lines.append("")

            let maxName = sectionChecks.map(\.name.count).max() ?? 0

            for check in sectionChecks {
                let icon: String
                switch check.status {
                case .ok:      icon = paint("✓", "32")
                case .warning: icon = paint("●", "33")
                case .error:   icon = paint("✗", "31")
                }
                let padded = check.name.padding(toLength: maxName, withPad: " ", startingAt: 0)
                let msg: String
                switch check.status {
                case .ok:      msg = check.message
                case .warning: msg = paint(check.message, "33")
                case .error:   msg = paint(check.message, "31")
                }
                lines.append("    \(icon) \(padded)  \(msg)")
                if let fix = check.fix {
                    let padding = String(repeating: " ", count: maxName + 6)
                    lines.append("    \(padding)\(paint(fix, "2"))")
                }
            }
        }

        let errors = checks.filter { $0.status == .error }.count
        let warnings = checks.filter { $0.status == .warning }.count
        let ok = checks.filter { $0.status == .ok }.count

        lines.append("")
        lines.append("  " + String(repeating: "─", count: 50))

        var summary: [String] = []
        if ok > 0 { summary.append(paint("\(ok) passed", "32")) }
        if warnings > 0 { summary.append(paint("\(warnings) optional", "33")) }
        if errors > 0 { summary.append(paint("\(errors) failed", "31")) }
        lines.append("  \(summary.joined(separator: " · "))")
        lines.append("")

        return lines.joined(separator: "\n")
    }
}
