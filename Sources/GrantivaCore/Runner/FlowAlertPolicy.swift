import Foundation

/// Opt-out (`--no-auto-accept-alerts`) from the runner's alert auto-accept
/// on iOS, for apps whose own alerts were being dismissed mid-flow.
///
/// The runner turns every `launchApp` whose permissions are all `allow`
/// (including the default, no `permissions:` at all) into a WebDriverAgent
/// session with `defaultAlertAction: accept`. WDA's alert monitor then accepts
/// any alert it sees while the flow polls for elements, and when none of the
/// alert's buttons match the runner's "Allow"/"OK" selector it presses the
/// alert's default button. An app's "Discard changes?" alert can vanish before
/// the flow reaches its `tapOn: "Keep Editing"`.
///
/// The monitor stays on by default: it is the only thing that answers system
/// prompts `simctl privacy` cannot pre-grant (notifications, tracking, local
/// network, Bluetooth). With the opt-out, Grantiva adds one `unset` entry to
/// each `launchApp`'s permissions in the staged copy of the flow (and of every
/// `runFlow` file it references): the runner skips `unset` entries when it
/// grants permissions, so the simulator grants are unchanged, but a map with
/// mixed values registers no alert monitor. The proper fix, accepting only
/// SpringBoard (system) alerts, belongs in grantiva-runner.
public enum FlowAlertPolicy {
    /// The permission entry Grantiva adds. Not a real permission service:
    /// the runner ignores `unset` entries when granting.
    public static let sentinelKey = "grantivaAppAlerts"
    static let sentinelEntry = "\(sentinelKey): unset"

    /// Rewrites every `launchApp` step so the runner registers no alert
    /// monitor while granting the same permissions as before. Inline
    /// `launchApp: {…}` steps are left as they are.
    public static func disableAutoAccept(in content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        var output: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard let step = FlowEnvironment.LaunchAppStep(line: line) else {
                output.append(line)
                index += 1
                continue
            }
            let itemIndent = String(repeating: " ", count: step.indent)
            let keyIndent = String(repeating: " ", count: step.indent + 4)

            switch step.form {
            case .bare:
                output.append("\(itemIndent)- launchApp:")
                output.append(contentsOf: defaultPermissionsBlock(indent: keyIndent))
                index += 1

            case .scalar(let appId):
                output.append("\(itemIndent)- launchApp:")
                output.append("\(keyIndent)appId: \(appId)")
                output.append(contentsOf: defaultPermissionsBlock(indent: keyIndent))
                index += 1

            case .mapping:
                output.append(line)
                index += 1
                var blockIndent: Int?
                var sawPermissions = false
                // Set after a `permissions:` line with no inline value: the
                // sentinel goes in front of the map's first entry, at its indent.
                var pendingPermissionsIndent: Int?
                while index < lines.count {
                    let bodyLine = lines[index]
                    let trimmed = bodyLine.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("#") {
                        output.append(bodyLine)
                        index += 1
                        continue
                    }
                    let indent = bodyLine.prefix { $0 == " " }.count
                    guard indent > step.indent else { break }
                    if blockIndent == nil { blockIndent = indent }

                    if let permissionsIndent = pendingPermissionsIndent {
                        pendingPermissionsIndent = nil
                        let pad = String(repeating: " ", count: indent > permissionsIndent ? indent : permissionsIndent + 2)
                        if indent > permissionsIndent {
                            output.append("\(pad)\(sentinelEntry)")
                        } else {
                            output.append(contentsOf: ["\(pad)all: allow", "\(pad)\(sentinelEntry)"])
                        }
                    }

                    if indent == blockIndent, let value = permissionsValue(trimmed) {
                        sawPermissions = true
                        if value.isEmpty {
                            output.append(bodyLine)
                            pendingPermissionsIndent = indent
                        } else {
                            output.append(String(repeating: " ", count: indent) + "permissions: " + inlineWithSentinel(value))
                        }
                    } else {
                        output.append(bodyLine)
                    }
                    index += 1
                }
                if let permissionsIndent = pendingPermissionsIndent {
                    let pad = String(repeating: " ", count: permissionsIndent + 2)
                    output.append(contentsOf: ["\(pad)all: allow", "\(pad)\(sentinelEntry)"])
                }
                if !sawPermissions {
                    let indent = String(repeating: " ", count: blockIndent ?? (step.indent + 4))
                    output.append(contentsOf: defaultPermissionsBlock(indent: indent))
                }
            }
        }
        return output.joined(separator: "\n")
    }

    /// `permissions:` with the runner's default grant plus the sentinel.
    private static func defaultPermissionsBlock(indent: String) -> [String] {
        ["\(indent)permissions:", "\(indent)  all: allow", "\(indent)  \(sentinelEntry)"]
    }

    /// The text after `permissions:` on a mapping line, or nil for any other key.
    private static func permissionsValue(_ trimmed: String) -> String? {
        guard trimmed.hasPrefix("permissions:") else { return nil }
        return trimmed.dropFirst("permissions:".count).trimmingCharacters(in: .whitespaces)
    }

    /// Adds the sentinel to an inline `{…}` map. An empty map means the
    /// runner's default (`all: allow`), so that is spelled out.
    private static func inlineWithSentinel(_ value: String) -> String {
        guard value.hasPrefix("{"), value.hasSuffix("}") else { return value }
        let inner = value.dropFirst().dropLast().trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return "{ all: allow, \(sentinelEntry) }" }
        return "{ \(sentinelEntry), \(inner) }"
    }
}

/// Stages rewritten copies of the `runFlow` files a flow references, so a
/// shared `setup.yaml`'s `launchApp` gets the same alert policy as the flow
/// that calls it. Pass `stage` as `FlowReferenceResolver.resolve`'s
/// `mapFile`. Each file is staged once; cycles reuse the first copy.
///
/// Only `runFlow` references are rewritten to absolute paths. Other relative
/// references in a staged child (`runScript`, `addMedia`, …) resolve from the
/// temp folder, the same as they already do in top-level staged flows.
final class FlowAlertStager {
    let directory: String
    private var staged: [String: String] = [:]
    /// Staged copy → the original file, for rewriting runner output.
    private(set) var pathMap: [String: String] = [:]

    init(directory: String) {
        self.directory = directory
    }

    func stage(_ absolutePath: String) throws -> String {
        if let existing = staged[absolutePath] { return existing }
        let fm = FileManager.default
        // A missing file is left for the runner to report against the
        // path the user wrote.
        guard fm.fileExists(atPath: absolutePath) else { return absolutePath }
        let stageDir = "\(directory)/\(staged.count)"
        try fm.createDirectory(atPath: stageDir, withIntermediateDirectories: true)
        let target = "\(stageDir)/\((absolutePath as NSString).lastPathComponent)"
        staged[absolutePath] = target
        pathMap[target] = absolutePath

        let content = try String(contentsOfFile: absolutePath, encoding: .utf8)
        let resolved = try FlowReferenceResolver.resolve(
            in: content,
            relativeTo: (absolutePath as NSString).deletingLastPathComponent,
            mapFile: stage
        )
        try FlowAlertPolicy.disableAutoAccept(in: resolved).write(toFile: target, atomically: true, encoding: .utf8)
        return target
    }
}
