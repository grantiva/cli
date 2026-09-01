import Foundation
import GrantivaAPI

/// Human-mode rendering for `grantiva console` results. Pure string builders —
/// callers put the result on stdout via `Output`.
enum ConsoleFormat {
    // MARK: - Generic table

    /// Renders a padded column table with a header rule, matching the
    /// `TableFormatter` look used elsewhere in the CLI.
    static func table(headers: [String], rows: [[String]]) -> String {
        var widths = headers.map(\.count)
        for row in rows {
            for (index, cell) in row.enumerated() where index < widths.count {
                widths[index] = max(widths[index], cell.count)
            }
        }

        func pad(_ text: String, to width: Int) -> String {
            text.padding(toLength: max(width, text.count), withPad: " ", startingAt: 0)
        }

        var lines: [String] = []
        let headerLine = headers.enumerated()
            .map { pad($1, to: widths[$0]) }
            .joined(separator: "  ")
            .trimmingCharacters(in: .whitespaces)
        lines.append(headers.enumerated().map { pad($1, to: widths[$0]) }.joined(separator: "  "))
        lines.append(String(repeating: "─", count: max(headerLine.count, widths.reduce(0, +) + (widths.count - 1) * 2)))
        for row in rows {
            let padded = row.enumerated().map { index, cell in
                index < widths.count ? pad(cell, to: widths[index]) : cell
            }
            lines.append(padded.joined(separator: "  ").trimmingRight())
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Flags

    static func flagsTable(_ flags: [OrgFlag]) -> String {
        guard !flags.isEmpty else { return "No flags found." }
        let rows = flags.map { flag in
            [
                flag.flagKey,
                flag.name,
                flag.valueType,
                flag.isActive ? "on" : "off",
                environmentSummary(flag.environmentValues),
                flag.ruleCount.map(String.init) ?? "-",
                flag.updatedAt.map(shortDate) ?? "-",
            ]
        }
        return table(headers: ["KEY", "NAME", "TYPE", "STATE", "ENVIRONMENTS", "RULES", "UPDATED"], rows: rows)
    }

    static func flagDetail(_ flag: OrgFlagDetail) -> String {
        var lines: [String] = []
        lines.append("\(flag.flagKey) — \(flag.name)")
        lines.append("  ID:     \(flag.id)")
        lines.append("  Type:   \(flag.valueType)")
        lines.append("  State:  \(flag.isActive ? "on" : "off")")
        if let description = flag.description, !description.isEmpty {
            lines.append("  Description: \(description)")
        }
        if let appId = flag.appId {
            lines.append("  App:    \(appId)")
        }
        if let values = flag.environmentValues, !values.isEmpty {
            lines.append("  Environment values:")
            for (env, value) in values.sorted(by: { $0.key < $1.key }) {
                lines.append("    \(env) = \(value)")
            }
        }
        if let rules = flag.rules, !rules.isEmpty {
            lines.append("  Rules (priority order):")
            for rule in rules.sorted(by: { $0.priority < $1.priority }) {
                let state = (rule.isActive ?? true) ? "" : " (inactive)"
                let rollout = rule.rolloutPercentage.map { $0 < 100 ? " rollout=\($0)%" : "" } ?? ""
                lines.append("    [\(rule.priority)] \(rule.name) → \(rule.value)\(rollout)\(state)")
            }
        }
        if let overrides = flag.overrides, !overrides.isEmpty {
            lines.append("  Overrides:")
            for override in overrides {
                let expiry = override.expiresAt.map { " (expires \(shortDate($0)))" } ?? ""
                lines.append("    \(override.deviceKeyId) → \(override.forcedValue)\(expiry)")
            }
        }
        if let updated = flag.updatedAt {
            lines.append("  Updated: \(shortDate(updated))")
        }
        return lines.joined(separator: "\n")
    }

    static func environmentSummary(_ values: [String: String]?) -> String {
        guard let values, !values.isEmpty else { return "-" }
        return values.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
    }

    // MARK: - Environments

    static func environmentsTable(_ environments: [OrgFlagEnvironment]) -> String {
        guard !environments.isEmpty else { return "No environments found." }
        let rows = environments
            .sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
            .map { env in
                [
                    env.slug,
                    env.name,
                    env.color ?? "-",
                    (env.isDefault ?? false) ? "yes" : "",
                    env.id,
                ]
            }
        return table(headers: ["SLUG", "NAME", "COLOR", "DEFAULT", "ID"], rows: rows)
    }

    // MARK: - Rules

    static func rulesTable(_ rules: [FlagRuleResponse]) -> String {
        guard !rules.isEmpty else { return "No rules found." }
        let rows = rules.sorted { $0.priority < $1.priority }.map { rule in
            [
                String(rule.priority),
                rule.name,
                conditionsSummary(rule.conditions),
                rule.value,
                "\(rule.rolloutPercentage)%",
                rule.isActive ? "on" : "off",
                rule.id,
            ]
        }
        return table(headers: ["PRI", "NAME", "CONDITIONS", "VALUE", "ROLLOUT", "STATE", "ID"], rows: rows)
    }

    static func conditionsSummary(_ conditions: [RuleCondition]) -> String {
        conditions
            .map { "\($0.attribute) \($0.operator) \($0.value.displayValue)" }
            .joined(separator: " AND ")
    }

    // MARK: - Overrides

    static func overridesTable(_ overrides: [OrgFlagOverride]) -> String {
        guard !overrides.isEmpty else { return "No overrides found." }
        let rows = overrides.map { override in
            [
                override.deviceKeyId,
                override.forcedValue,
                override.expiresAt.map(shortDate) ?? "never",
                override.id,
            ]
        }
        return table(headers: ["DEVICE", "VALUE", "EXPIRES", "ID"], rows: rows)
    }

    // MARK: - History

    static func historyTable(_ entries: [FlagHistoryEntry]) -> String {
        guard !entries.isEmpty else { return "No history found." }
        let rows = entries.map { entry in
            [
                entry.createdAt.map(shortDate) ?? "-",
                entry.action,
                entry.environment ?? "-",
                changeSummary(old: entry.oldValue, new: entry.newValue),
                entry.actor ?? "-",
            ]
        }
        return table(headers: ["WHEN", "ACTION", "ENV", "CHANGE", "ACTOR"], rows: rows)
    }

    private static func changeSummary(old: String?, new: String?) -> String {
        switch (old, new) {
        case (nil, nil): return "-"
        case (nil, .some(let new)): return "→ \(new)"
        case (.some(let old), nil): return "\(old) →"
        case (.some(let old), .some(let new)): return "\(old) → \(new)"
        }
    }

    // MARK: - Evaluation Trace

    /// Renders the full dry-run rule trace: the resolved value, then every
    /// rule in priority order with per-condition expected/actual/passed.
    static func evaluationTrace(_ result: FlagEvaluationResponse) -> String {
        var lines: [String] = []
        lines.append("Flag: \(result.flagKey) (\(result.valueType)) — environment: \(result.environment)")
        if let matched = result.matchedRule {
            lines.append("Resolved value: \(result.resolvedValue)   (matched rule: \"\(matched)\")")
        } else {
            lines.append("Resolved value: \(result.resolvedValue)   (default — no rules matched)")
        }

        guard !result.trace.isEmpty else {
            lines.append("")
            lines.append("No active targeting rules on this flag.")
            return lines.joined(separator: "\n")
        }

        lines.append("")
        let count = result.trace.count
        lines.append("Rule trace (\(count) rule\(count == 1 ? "" : "s"), priority order):")
        lines.append("")

        for rule in result.trace.sorted(by: { $0.priority < $1.priority }) {
            let icon = rule.matched ? "✓" : "✗"
            var headline = "  \(icon) [\(rule.priority)] \(rule.ruleName)"
            if rule.matched {
                headline += " — MATCHED → value: \(rule.value)"
            } else {
                headline += " — not matched"
            }
            if rule.rolloutPercentage < 100 {
                let rolloutNote = rule.matched || rule.passedRollout
                    ? "rollout \(rule.rolloutPercentage)%: in"
                    : "rollout \(rule.rolloutPercentage)%: out"
                headline += "   (\(rolloutNote))"
            }
            lines.append(headline)

            let attrWidth = rule.conditions.map { "\($0.attribute) \($0.operator)".count }.max() ?? 0
            let expectedWidth = rule.conditions.map { "expected: \($0.expected)".count }.max() ?? 0
            for condition in rule.conditions {
                let conditionIcon = condition.passed ? "✓" : "✗"
                let attr = "\(condition.attribute) \(condition.operator)"
                    .padding(toLength: attrWidth, withPad: " ", startingAt: 0)
                let expected = "expected: \(condition.expected)"
                    .padding(toLength: expectedWidth, withPad: " ", startingAt: 0)
                let actual = condition.actual.map { "actual: \($0)" } ?? "actual: (not provided)"
                lines.append("      \(conditionIcon) \(attr)   \(expected)   \(actual)")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Dates

    /// Trims an ISO8601 timestamp to a readable "YYYY-MM-DD HH:MM" form; any
    /// other string passes through untouched.
    static func shortDate(_ iso: String) -> String {
        guard iso.count >= 16, iso[iso.index(iso.startIndex, offsetBy: 10)] == "T" else { return iso }
        let date = String(iso.prefix(10))
        let start = iso.index(iso.startIndex, offsetBy: 11)
        let end = iso.index(iso.startIndex, offsetBy: 16)
        return "\(date) \(iso[start..<end])"
    }
}

private extension String {
    func trimmingRight() -> String {
        guard let last = lastIndex(where: { $0 != " " }) else { return "" }
        return String(self[...last])
    }
}
