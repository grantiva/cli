import Foundation
import GrantivaAPI
import GrantivaCore

/// Human-mode rendering for `console apps`, `console claims`, and
/// `console devices`.
enum ConsoleOrgFormat {
    // MARK: - Apps

    static func appsTable(_ apps: [OrgApp]) -> String {
        guard !apps.isEmpty else { return "No apps registered." }
        let rows = apps.map { app in
            [
                app.bundleId,
                app.appName,
                app.teamId,
                app.isActive ? "active" : "inactive",
                app.isPrimary ? "yes" : "",
                app.createdAt.map(ConsoleFormat.shortDate) ?? "-",
            ]
        }
        return ConsoleFormat.table(headers: ["BUNDLE ID", "NAME", "TEAM", "STATE", "PRIMARY", "CREATED"], rows: rows)
    }

    static func appDetail(_ app: OrgApp) -> String {
        var lines: [String] = []
        lines.append("\(app.bundleId) — \(app.appName)\(app.isPrimary ? " (primary)" : "")")
        lines.append("  ID:        \(app.id)")
        lines.append("  Team ID:   \(app.teamId)")
        lines.append("  State:     \(app.isActive ? "active" : "inactive")")
        if let description = app.description, !description.isEmpty {
            lines.append("  Description: \(description)")
        }
        lines.append("  Analytics: \(app.analyticsEnabled ? "on" : "off")   Webhooks: \(app.webhookEnabled ? "on" : "off")")
        if let created = app.createdAt { lines.append("  Created:   \(ConsoleFormat.shortDate(created))") }
        if let updated = app.updatedAt { lines.append("  Updated:   \(ConsoleFormat.shortDate(updated))") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Claims

    static func claimsTable(_ claims: [OrgClaim]) -> String {
        guard !claims.isEmpty else { return "No custom claims." }
        let rows = claims.map { claim in
            [
                String(claim.priority),
                claim.claimKey,
                claim.claimName,
                claim.claimType,
                claim.dataType,
                claim.isActive ? "active" : "inactive",
                configurationSummary(claim),
            ]
        }
        return ConsoleFormat.table(headers: ["PRI", "KEY", "NAME", "TYPE", "DATA", "STATE", "CONFIG"], rows: rows)
    }

    static func configurationSummary(_ claim: OrgClaim) -> String {
        switch claim.claimType {
        case "static": return claim.staticValue.map { "= \($0)" } ?? "-"
        case "conditional":
            if case .array(let rules)? = claim.conditionalRules { return "\(rules.count) rule\(rules.count == 1 ? "" : "s")" }
            return "-"
        case "dynamic": return claim.dynamicExpression ?? "-"
        case "external":
            if case .object(let config)? = claim.externalConfig, case .string(let endpoint)? = config["endpoint"] { return endpoint }
            return "-"
        default: return "-"
        }
    }

    static func claimDetail(_ claim: OrgClaim) throws -> String {
        var lines: [String] = []
        lines.append("\(claim.claimKey) — \(claim.claimName)")
        lines.append("  ID:        \(claim.id)")
        lines.append("  Type:      \(claim.claimType) (\(claim.dataType))")
        lines.append("  State:     \(claim.isActive ? "active" : "inactive")   Priority: \(claim.priority)")
        if let description = claim.description, !description.isEmpty {
            lines.append("  Description: \(description)")
        }
        switch claim.claimType {
        case "static":
            lines.append("  Value:     \(claim.staticValue ?? "-")")
        case "dynamic":
            lines.append("  Expression: \(claim.dynamicExpression ?? "-")")
        case "conditional":
            lines.append("  Rules:")
            lines.append(indent(try JSONOutput.string(claim.conditionalRules ?? .null)))
        case "external":
            lines.append("  External:")
            lines.append(indent(try JSONOutput.string(claim.externalConfig ?? .null)))
        default:
            break
        }
        if let validation = claim.validationRules {
            lines.append("  Validation:")
            lines.append(indent(try JSONOutput.string(validation)))
        }
        if let updated = claim.updatedAt { lines.append("  Updated:   \(ConsoleFormat.shortDate(updated))") }
        return lines.joined(separator: "\n")
    }

    static func claimEvaluation(_ result: OrgClaimTestResponse) -> String {
        var lines: [String] = []
        lines.append("Claim: \(result.claimKey) (\(result.dataType))")
        lines.append("Evaluated value: \(result.evaluatedValue ?? "null")")
        lines.append("Took \(String(format: "%.1f", result.evaluationTimeMs)) ms")
        if let errors = result.errors, !errors.isEmpty {
            lines.append("Errors:")
            for error in errors { lines.append("  - \(error)") }
        }
        return lines.joined(separator: "\n")
    }

    private static func indent(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { "    \($0)" }.joined(separator: "\n")
    }

    // MARK: - Devices

    static func devicesList(_ list: OrgDeviceList) -> String {
        guard !list.items.isEmpty else { return "No devices found." }
        let rows = list.items.map { device in
            [
                device.keyId,
                device.appName ?? "-",
                device.deviceModel ?? "-",
                device.osVersion ?? "-",
                "\(device.riskScore) \(ConsoleAnalyticsFormat.riskBand(device.riskScore))",
                device.jailbreakDetected ? "yes" : "",
                String(device.attestationCount),
                ConsoleFormat.shortDate(device.lastAttestation),
            ]
        }
        let table = ConsoleFormat.table(
            headers: ["KEY ID", "APP", "MODEL", "OS", "RISK", "JAILBROKEN", "ATTESTS", "LAST SEEN"],
            rows: rows
        )
        let pages = max(Int((Double(list.total) / Double(max(list.per, 1))).rounded(.up)), 1)
        return table + "\n\nPage \(list.page) of \(pages) · \(list.total) device\(list.total == 1 ? "" : "s")"
    }

    static func deviceDetail(_ device: OrgDeviceDetail) -> String {
        var lines: [String] = []
        lines.append("Device \(device.keyId)")
        if let appName = device.appName { lines.append("  App:              \(appName)") }
        lines.append("  Model:            \(device.deviceModel ?? "-")")
        lines.append("  OS:               \(device.osVersion ?? "-")")
        lines.append("  App version:      \(device.appVersion ?? "-")\(device.firstAppVersion.map { " (first seen on \($0))" } ?? "")")
        lines.append("  Risk score:       \(device.riskScore) (\(ConsoleAnalyticsFormat.riskBand(device.riskScore)))")
        lines.append("  Jailbroken:       \(device.jailbreakDetected ? "yes" : "no")")
        if let developmentBuild = device.isDevelopmentBuild {
            lines.append("  Development build: \(developmentBuild ? "yes" : "no")")
        }
        if let appStoreReceipt = device.appStoreReceipt {
            lines.append("  App Store receipt: \(appStoreReceipt ? "present" : "absent")")
        }
        lines.append("  Attestations:     \(device.attestationCount)")
        if let clean = device.consecutiveCleanAttestations {
            lines.append("  Clean streak:     \(clean)")
        }
        lines.append("  Suspicious:       \(device.suspiciousEvents)\(device.lastSuspiciousEventAt.map { " (last \(ConsoleFormat.shortDate($0)))" } ?? "")")
        if let country = device.lastCountry { lines.append("  Last country:     \(country)") }
        if let permissions = device.permissions, !permissions.isEmpty {
            lines.append("  Permissions:      \(permissions.joined(separator: ", "))")
        }
        if let subject = device.subjectId { lines.append("  Subject:          \(subject)") }
        lines.append("  First seen:       \(ConsoleFormat.shortDate(device.firstSeen))")
        lines.append("  Last attestation: \(ConsoleFormat.shortDate(device.lastAttestation))")
        lines.append("")
        lines.append("Recent events:")
        if device.recentEvents.isEmpty {
            lines.append("No events found.")
        } else {
            let rows = device.recentEvents.map { event in
                [
                    event.createdAt.map(ConsoleFormat.shortDate) ?? "-",
                    event.eventType,
                    event.success ? "ok" : "failed",
                    String(event.riskScore),
                    event.errorReason ?? "",
                ]
            }
            lines.append(ConsoleFormat.table(headers: ["WHEN", "TYPE", "RESULT", "RISK", "ERROR"], rows: rows))
        }
        return lines.joined(separator: "\n")
    }
}
