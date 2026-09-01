import Foundation
import GrantivaAPI

/// Human-mode rendering for `console analytics` and `console devices`.
enum ConsoleAnalyticsFormat {
    // MARK: - Overview

    static func overview(_ overview: AttestationAnalytics, days: Int) -> String {
        var lines: [String] = []
        lines.append("Attestations — last \(days) day\(days == 1 ? "" : "s") (the server samples the most recent 100 events)")
        lines.append("  Total:          \(overview.totalAttestations)")
        lines.append("  Successful:     \(overview.successfulAttestations)")
        lines.append("  Failed:         \(overview.failedAttestations)")
        lines.append("  Success rate:   \(percent(overview.successRate))")
        lines.append("  Unique devices: \(overview.uniqueDevices)")
        lines.append("  Average risk:   \(oneDecimal(overview.averageRiskScore))")
        lines.append("  Suspicious:     \(overview.suspiciousEvents)")
        lines.append("")
        lines.append("Recent events:")
        lines.append(eventsTable(overview.recentEvents))
        return lines.joined(separator: "\n")
    }

    // MARK: - Events

    static func events(_ response: PaginatedEventsResponse) -> String {
        var lines: [String] = [eventsTable(response.data)]
        let meta = response.meta
        lines.append("")
        lines.append("Page \(meta.page) of \(meta.totalPages) · \(meta.total) event\(meta.total == 1 ? "" : "s") · \(meta.perPage) per page")
        return lines.joined(separator: "\n")
    }

    static func eventsTable(_ events: [AttestationEventResponse]) -> String {
        guard !events.isEmpty else { return "No events found." }
        let rows = events.map { event in
            [
                ConsoleFormat.shortDate(event.createdAt),
                event.eventType,
                event.keyId,
                event.success ? "ok" : "failed",
                String(event.riskScore),
                event.errorReason ?? "",
            ]
        }
        return ConsoleFormat.table(headers: ["WHEN", "TYPE", "KEY ID", "RESULT", "RISK", "ERROR"], rows: rows)
    }

    // MARK: - Risk

    static func risk(_ report: RiskAssessmentReport) -> String {
        var lines: [String] = []
        lines.append("Risk assessment — \(periodLabel(report.period))")
        lines.append("  Devices seen:   \(report.totalDevices)")
        lines.append("  Average risk:   \(oneDecimal(report.averageRiskScore))")
        lines.append("  Distribution:   \(distribution(report.riskDistribution))")
        lines.append("")
        lines.append("Critical-risk devices (score 76+):")
        if report.highRiskDevices.isEmpty {
            lines.append("  none")
        } else {
            let rows = report.highRiskDevices.map { device in
                [
                    device.keyId,
                    device.deviceModel ?? "-",
                    String(device.riskScore),
                    device.jailbreakDetected ? "yes" : "no",
                    String(device.suspiciousEvents),
                    ConsoleFormat.shortDate(device.lastAttestation),
                ]
            }
            lines.append(ConsoleFormat.table(
                headers: ["KEY ID", "MODEL", "RISK", "JAILBROKEN", "SUSPICIOUS", "LAST SEEN"],
                rows: rows
            ))
        }
        lines.append("")
        lines.append("Recent suspicious activity:")
        if report.recentSecurityEvents.isEmpty {
            lines.append("  none")
        } else {
            let rows = report.recentSecurityEvents.map { event in
                [ConsoleFormat.shortDate(event.timestamp), event.eventType, event.keyId, String(event.riskScore)]
            }
            lines.append(ConsoleFormat.table(headers: ["WHEN", "TYPE", "KEY ID", "RISK"], rows: rows))
        }
        return lines.joined(separator: "\n")
    }

    /// `low 12 · medium 3 · high 1 · critical 0`, in band order.
    static func distribution(_ buckets: [String: Int]) -> String {
        ["low", "medium", "high", "critical"]
            .map { "\($0) \(buckets[$0] ?? 0)" }
            .joined(separator: " · ")
    }

    // MARK: - Compliance

    static func compliance(_ report: ComplianceReport, showAll: Bool) -> String {
        var lines: [String] = []
        lines.append("Compliance — \(periodLabel(report.period))")
        lines.append("  Devices:         \(report.totalDevices)")
        lines.append("  Compliant:       \(report.compliantDevices)")
        lines.append("  Non-compliant:   \(report.nonCompliantDevices)")
        lines.append("  Compliance rate: \(percent(report.complianceRate))")
        lines.append("")
        lines.append("Violations:")
        if report.violationSummary.isEmpty {
            lines.append("  none")
        } else {
            for (violation, count) in report.violationSummary.sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }) {
                lines.append("  \(count.description.padding(toLength: 6, withPad: " ", startingAt: 0))\(violation)")
            }
        }
        lines.append("")
        let devices = showAll ? report.deviceCompliance : report.deviceCompliance.filter { !$0.isCompliant }
        lines.append(showAll ? "Devices:" : "Non-compliant devices:")
        if devices.isEmpty {
            lines.append("  none")
        } else {
            let rows = devices.map { device in
                [
                    device.keyId,
                    device.deviceModel ?? "-",
                    device.osVersion ?? "-",
                    device.isCompliant ? "yes" : "no",
                    String(device.complianceScore),
                    device.violations.joined(separator: ", "),
                ]
            }
            lines.append(ConsoleFormat.table(
                headers: ["KEY ID", "MODEL", "OS", "COMPLIANT", "SCORE", "VIOLATIONS"],
                rows: rows
            ))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Device detail

    static func device(_ detail: DeviceDetailsResponse) -> String {
        let profile = detail.deviceProfile
        var lines: [String] = []
        lines.append("Device \(detail.keyId)")
        lines.append("  Model:            \(profile.deviceModel ?? "-")")
        lines.append("  OS:               \(profile.osVersion ?? "-")")
        lines.append("  App version:      \(profile.appVersion ?? "-")\(profile.firstAppVersion.map { " (first seen on \($0))" } ?? "")")
        lines.append("  Risk score:       \(profile.riskScore) (\(riskBand(profile.riskScore)))")
        lines.append("  Jailbroken:       \(profile.jailbreakDetected ? "yes" : "no")")
        if let dev = profile.isDevelopmentBuild {
            lines.append("  Development build: \(dev ? "yes" : "no")")
        }
        if let receipt = profile.appStoreReceipt {
            lines.append("  App Store receipt: \(receipt ? "present" : "absent")")
        }
        lines.append("  Attestations:     \(profile.attestationCount)")
        if let clean = profile.consecutiveCleanAttestations {
            lines.append("  Clean streak:     \(clean)")
        }
        lines.append("  Suspicious:       \(profile.suspiciousEvents)\(profile.lastSuspiciousEventAt.map { " (last \(ConsoleFormat.shortDate($0)))" } ?? "")")
        if let country = profile.lastCountry {
            lines.append("  Last country:     \(country)")
        }
        if let permissions = profile.permissions, !permissions.isEmpty {
            lines.append("  Permissions:      \(permissions.joined(separator: ", "))")
        }
        lines.append("  First seen:       \(ConsoleFormat.shortDate(profile.firstSeen))")
        lines.append("  Last attestation: \(ConsoleFormat.shortDate(profile.lastAttestation))")
        lines.append("")
        let compliance = detail.complianceStatus
        lines.append("Compliance: \(compliance.isCompliant ? "compliant" : "NON-COMPLIANT") (score \(compliance.score), checked \(ConsoleFormat.shortDate(compliance.lastChecked)))")
        for violation in compliance.violations {
            lines.append("  - \(violation.description)")
        }
        lines.append("")
        lines.append("Recent events:")
        lines.append(eventsTable(detail.recentEvents))
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    static func riskBand(_ score: Int) -> String {
        switch score {
        case ..<21: return "low"
        case 21...50: return "medium"
        case 51...75: return "high"
        default: return "critical"
        }
    }

    static func percent(_ value: Double) -> String {
        "\(oneDecimal(value))%"
    }

    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// `[start, end]` → `2026-08-25 → 2026-09-01`; anything else printed as-is.
    static func periodLabel(_ period: [String]) -> String {
        guard period.count == 2 else { return period.joined(separator: " → ") }
        return "\(String(period[0].prefix(10))) → \(String(period[1].prefix(10)))"
    }
}
