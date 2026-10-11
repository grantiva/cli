import Foundation

/// Brings a report directory to a terminal state after grantiva stopped the
/// runner (its `--timeout` cap, or an interrupt).
///
/// The runner leaves report.json, the per-flow files and the JUnit file as
/// they were last flushed, which for a run cut off mid-step is `running`. The
/// ready file already says `failed` or `interrupted`; the kept report is the
/// run's artifact of record and has to agree with it.
enum RunnerReportFinalizer {
    static let terminal: Set<String> = RunnerReportIndex.terminalStatuses

    /// Rewrites every non-terminal status to `status` (`failed` or
    /// `interrupted`) with `reason` as the error, recounts the summaries and
    /// records the failures in the JUnit file. Best-effort: an unreadable
    /// file is left as it is.
    static func finalize(reportDir: String, status: String, reason: String) {
        let root = URL(fileURLWithPath: reportDir, isDirectory: true)
        let reportURL = root.appendingPathComponent("report.json")
        guard var report = readJSON(reportURL) else { return }
        let now = ISO8601DateFormatter().string(from: Date())

        var finalizedFlows: [(name: String, file: String?)] = []
        var flows = report["flows"] as? [[String: Any]] ?? []
        for index in flows.indices {
            var flow = flows[index]
            if let dataFile = flow["dataFile"] as? String {
                finalizeFlowData(at: root.appendingPathComponent(dataFile), status: status, reason: reason, now: now)
            }
            let current = flow["status"] as? String ?? "pending"
            if !terminal.contains(current) {
                flow["status"] = status
                if flow["error"] == nil { flow["error"] = reason }
                if flow["endTime"] == nil { flow["endTime"] = now }
                if var commands = flow["commands"] as? [String: Any] {
                    let running = commands["running"] as? Int ?? 0
                    let pending = commands["pending"] as? Int ?? 0
                    commands["failed"] = (commands["failed"] as? Int ?? 0) + running
                    commands["skipped"] = (commands["skipped"] as? Int ?? 0) + pending
                    commands["running"] = 0
                    commands["pending"] = 0
                    commands.removeValue(forKey: "current")
                    flow["commands"] = commands
                }
                finalizedFlows.append((flow["name"] as? String ?? "flow", flow["sourceFile"] as? String))
            }
            flows[index] = flow
        }
        report["flows"] = flows

        let statuses = flows.map { $0["status"] as? String ?? "" }
        var summary = report["summary"] as? [String: Any] ?? [:]
        summary["total"] = flows.count
        summary["passed"] = statuses.filter { $0 == "passed" }.count
        summary["skipped"] = statuses.filter { $0 == "skipped" }.count
        summary["failed"] = statuses.filter { !["passed", "skipped"].contains($0) }.count
        summary["running"] = 0
        summary["pending"] = 0
        report["summary"] = summary
        let overall = report["status"] as? String ?? "running"
        if !terminal.contains(overall) || overall == "passed" && statuses.contains(where: { $0 != "passed" && $0 != "skipped" }) {
            report["status"] = status
        }
        if report["endTime"] == nil { report["endTime"] = now }
        writeJSON(report, to: reportURL)

        guard !finalizedFlows.isEmpty else { return }
        finalizeJUnit(at: root.appendingPathComponent("junit-report.xml"), flows: finalizedFlows.map(\.name), reason: reason)
    }

    private static func finalizeFlowData(at url: URL, status: String, reason: String, now: String) {
        guard var data = readJSON(url) else { return }
        var commands = data["commands"] as? [[String: Any]] ?? []
        var changed = false
        for index in commands.indices {
            switch commands[index]["status"] as? String {
            case "running":
                commands[index]["status"] = "failed"
                if commands[index]["error"] == nil {
                    commands[index]["error"] = ["type": "timeout", "message": reason]
                }
                if commands[index]["endTime"] == nil { commands[index]["endTime"] = now }
                changed = true
            case "pending":
                commands[index]["status"] = "skipped"
                changed = true
            default:
                break
            }
        }
        let unfinished = (data["status"] as? String).map { !terminal.contains($0) } ?? false
        if changed || unfinished {
            data["status"] = status
            if data["error"] == nil { data["error"] = reason }
        }
        if data["endTime"] == nil { data["endTime"] = now }
        data["commands"] = commands
        writeJSON(data, to: url)
    }

    /// Adds a `<failure>` to each named test case that has none, and raises
    /// the suite failure counts to match.
    private static func finalizeJUnit(at url: URL, flows: [String], reason: String) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        var result = text
        var added = 0
        let message = RunnerReportRewriter.xmlEscaped(reason)
        for name in flows {
            let escaped = RunnerReportRewriter.xmlEscaped(name)
            guard let open = result.range(of: "<testcase name=\"\(escaped)\"") else { continue }
            guard let tagEnd = result[open.upperBound...].firstIndex(of: ">") else { continue }
            let selfClosing = result[result.index(before: tagEnd)] == "/"
            let failure = "\n      <failure message=\"\(message)\" type=\"timeout\"></failure>"
            if selfClosing {
                let slash = result.index(before: tagEnd)
                result.replaceSubrange(slash...tagEnd, with: ">\(failure)\n    </testcase>")
            } else {
                let close = result[tagEnd...].range(of: "</testcase>")
                let body = close.map { result[tagEnd..<$0.lowerBound] } ?? ""
                guard !body.contains("<failure") else { continue }
                result.insert(contentsOf: failure, at: result.index(after: tagEnd))
            }
            added += 1
        }
        guard added > 0 else { return }
        result = bumpingAttribute("failures", by: added, in: result)
        try? Data(result.utf8).write(to: url, options: .atomic)
    }

    /// `failures="N"` on `<testsuites>` and `<testsuite>` becomes `N + added`.
    private static func bumpingAttribute(_ name: String, by added: Int, in text: String) -> String {
        var result = ""
        var rest = Substring(text)
        for tag in ["<testsuites", "<testsuite "] {
            guard let tagRange = rest.range(of: tag),
                  let attribute = rest[tagRange.upperBound...].range(of: "\(name)=\""),
                  let close = rest[attribute.upperBound...].firstIndex(of: "\""),
                  let value = Int(rest[attribute.upperBound..<close]) else { continue }
            result += rest[..<attribute.upperBound] + String(value + added)
            rest = rest[close...]
        }
        return result + rest
    }

    static func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func writeJSON(_ object: [String: Any], to url: URL) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
