import Foundation

/// Reads the per-command record the runner keeps for each flow
/// (`report.json` → `flows/<id>.json`), so step lists, durations and failure
/// details come from what the runner measured instead of being synthesised.
enum RunnerReportSteps {
    struct Report: Decodable {
        struct Flow: Decodable {
            let index: Int?
            let id: String?
            let name: String?
            let status: String?
            let error: String?
            let dataFile: String?
        }
        let status: String?
        let flows: [Flow]?
    }

    struct FlowData: Decodable {
        struct Command: Decodable {
            struct Failure: Decodable {
                let type: String?
                let message: String?
            }
            let index: Int?
            let type: String?
            let yaml: String?
            let status: String?
            /// Milliseconds, as the runner measured it.
            let duration: Double?
            let error: Failure?
            let artifacts: [String: String]?
        }
        let commands: [Command]?
    }

    static func report(in reportDir: String) -> Report? {
        let root = URL(fileURLWithPath: reportDir, isDirectory: true).standardizedFileURL
        guard let data = FileManager.default.contents(atPath: root.appendingPathComponent("report.json").path) else {
            return nil
        }
        return try? JSONDecoder().decode(Report.self, from: data)
    }

    static func commands(of flow: Report.Flow, in reportDir: String) -> [FlowData.Command] {
        guard let dataFile = flow.dataFile else { return [] }
        let root = URL(fileURLWithPath: reportDir, isDirectory: true).standardizedFileURL
        let url = root.appendingPathComponent(dataFile).standardizedFileURL
        // The report names the file; never read outside the report dir.
        guard url.path.hasPrefix(root.path + "/"),
              let data = FileManager.default.contents(atPath: url.path),
              let flowData = try? JSONDecoder().decode(FlowData.self, from: data) else {
            return []
        }
        return flowData.commands ?? []
    }

    /// Seconds from the runner's milliseconds; nil when it recorded none.
    static func seconds(_ milliseconds: Double?) -> Double? {
        milliseconds.map { $0.rounded() / 1000 }
    }

    /// One step per command that ran, with the runner's status, duration and
    /// (on failure) message. Skipped and pending commands never ran.
    static func steps(_ commands: [FlowData.Command]) -> [StepResult] {
        commands.compactMap { command in
            let action = command.yaml ?? command.type ?? "step"
            let duration = seconds(command.duration)
            switch command.status {
            case "passed":
                return StepResult(action: action, status: .passed, duration: duration)
            case "failed", "error":
                return StepResult(action: action, status: .failed, duration: duration, message: command.error?.message)
            case "running":
                return StepResult(action: action, status: .failed, duration: duration, message: "Did not finish")
            default:
                return nil
            }
        }
    }

    /// The first command that failed (or was still running when the runner
    /// stopped), with the flow it belongs to.
    struct Failure: Equatable {
        let flowName: String
        /// The command's position in its flow's command list.
        let commandIndex: Int?
        let action: String
        let message: String?
        let errorType: String?
        /// True for a command cut off while running (a timeout or interrupt).
        let unfinished: Bool

        /// `<flow>: <step>: <message>`, the line `run` reports.
        var line: String {
            [flowName, action, message].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
        }

        /// Element-not-found and not-visible failures are about the UI tree,
        /// so the remedy is to look at it.
        var wantsHierarchyHint: Bool {
            guard !unfinished else { return false }
            let text = (message ?? "").lowercased()
            switch errorType {
            case "element_not_found":
                return true
            case "assertion":
                return text.contains("not visible") || text.contains("not found")
            case nil:
                return text.hasPrefix("element not found") || text.hasPrefix("element not visible")
            default:
                return false
            }
        }
    }

    static let hierarchyHint = "Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree."

    static func firstFailure(in reportDir: String) -> Failure? {
        guard let report = report(in: reportDir) else { return nil }
        for flow in report.flows ?? [] {
            let name = flow.name ?? "flow"
            let commands = commands(of: flow, in: reportDir)
            for (position, command) in commands.enumerated()
            where ["failed", "error", "running"].contains(command.status ?? "") {
                return Failure(
                    flowName: name,
                    commandIndex: command.index ?? position,
                    action: command.yaml ?? command.type ?? "step",
                    message: command.error?.message,
                    errorType: command.error?.type,
                    unfinished: command.status == "running"
                )
            }
            if let status = flow.status, !["passed", "skipped"].contains(status), let error = flow.error {
                return Failure(
                    flowName: name, commandIndex: nil, action: "", message: error,
                    errorType: nil, unfinished: status == "running"
                )
            }
        }
        return nil
    }
}
