import Foundation

/// What a failed runner session leaves behind for `run --json`.
///
/// `runFlowFiles` throws when the runner exits non-zero, and the default
/// report dir is deleted as it unwinds, so the caller cannot read report.json
/// afterwards. The session fills this in from the report before throwing.
public final class RunnerFailureReport: @unchecked Sendable {
    private let lock = NSLock()
    private var storedCaptures: [ScreenCapture] = []
    private var storedReportDir: String?

    public init() {}

    /// One capture per flow in the runner's report, with a step per command
    /// that ran (the failed one carries the runner's error message).
    public var captures: [ScreenCapture] {
        lock.lock()
        defer { lock.unlock() }
        return storedCaptures
    }

    /// The preserved `--report-dir`, or nil for an ephemeral one.
    public var reportDir: String? {
        lock.lock()
        defer { lock.unlock() }
        return storedReportDir
    }

    func record(reportDir: String, preservedReportDir: String?) {
        let captures = Self.captures(reportDir: reportDir)
        lock.lock()
        defer { lock.unlock() }
        storedCaptures = captures
        storedReportDir = preservedReportDir
    }

    private struct Report: Decodable {
        struct Flow: Decodable {
            let name: String?
            let status: String?
            let error: String?
            let dataFile: String?
        }
        let flows: [Flow]?
    }

    private struct FlowData: Decodable {
        struct Command: Decodable {
            struct Failure: Decodable {
                let message: String?
            }
            let type: String?
            let yaml: String?
            let status: String?
            let error: Failure?
        }
        let commands: [Command]?
    }

    static func captures(reportDir: String) -> [ScreenCapture] {
        let root = URL(fileURLWithPath: reportDir, isDirectory: true).standardizedFileURL
        guard let data = FileManager.default.contents(atPath: root.appendingPathComponent("report.json").path),
              let report = try? JSONDecoder().decode(Report.self, from: data) else {
            return []
        }
        return (report.flows ?? []).map { flow in
            let name = flow.name ?? "flow"
            var steps: [StepResult] = commands(of: flow, in: root).compactMap { command in
                let action = command.yaml ?? command.type ?? "step"
                switch command.status {
                case "passed":
                    return StepResult(action: action, status: .passed, duration: 0)
                case "failed", "error":
                    return StepResult(action: action, status: .failed, duration: 0, message: command.error?.message)
                case "running":
                    return StepResult(action: action, status: .failed, duration: 0, message: "Did not finish")
                default:
                    // skipped / pending: never ran.
                    return nil
                }
            }
            // A flow that did not pass must show a failed step even when no
            // command failed (setup error, skipped after fail-fast, cut off).
            if flow.status != "passed", !steps.contains(where: { $0.status == .failed }) {
                steps.append(StepResult(
                    action: "Run flow \"\(name)\"",
                    status: .failed,
                    duration: 0,
                    message: flow.error ?? flow.status
                ))
            }
            if steps.isEmpty {
                steps.append(StepResult(action: "Run flow \"\(name)\"", status: .passed, duration: 0))
            }
            return ScreenCapture(screenName: name, path: "", sizeBytes: 0, steps: steps)
        }
    }

    private static func commands(of flow: Report.Flow, in root: URL) -> [FlowData.Command] {
        guard let dataFile = flow.dataFile else { return [] }
        let url = root.appendingPathComponent(dataFile).standardizedFileURL
        // The report names the file; never read outside the report dir.
        guard url.path.hasPrefix(root.path + "/"),
              let data = FileManager.default.contents(atPath: url.path),
              let flowData = try? JSONDecoder().decode(FlowData.self, from: data) else {
            return []
        }
        return flowData.commands ?? []
    }
}
