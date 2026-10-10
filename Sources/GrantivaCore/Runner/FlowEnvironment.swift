import Foundation
import Yams

/// Parses `--env KEY=VALUE` pairs and injects them into a flow's `launchApp`
/// steps.
///
/// On iOS the runner forwards `launchApp: environment:` to the app as process
/// environment. On Android the only launch-time channel is intent extras, which
/// the runner fills from `launchApp: arguments:` (it ignores `environment:`
/// there), so the same values go into `arguments:` as string extras. Injection
/// happens on the staged copy of the flow — the same copy that already receives
/// the resolved `appId` — so the user's file is never modified.
public enum FlowEnvironment {
    /// The `launchApp` field the runner delivers to the app on `platform`.
    public static func launchField(for platform: Platform) -> String {
        platform == .android ? "arguments" : "environment"
    }

    /// Prepares a flow's launch data for `platform`: the flow header's `env:`
    /// block and `--env` (which wins) are injected into every `launchApp`, and
    /// on Android a step's own `environment:` becomes `arguments:`. A value a
    /// step declares itself beats the header but not `--env`.
    public static func apply(
        to content: String,
        environment: [String: String],
        platform: Platform
    ) -> (yaml: String, injected: Bool) {
        let field = launchField(for: platform)
        var yaml = content
        if platform == .android {
            yaml = renameLaunchField(in: yaml, from: "environment", to: field)
        }
        let header = headerEnvironment(content)
        if !header.isEmpty {
            yaml = inject(yaml, environment: header, field: field, overrideExisting: false).yaml
        }
        return inject(yaml, environment: environment, field: field)
    }

    /// The flow header's `env:` mapping (the config document before `---`,
    /// split the way `MaestroFlowParser` splits it), with scalar values as
    /// strings and null as "". Keys that are not valid launch keys (see
    /// `isValidKey`) are left out. Empty when the flow has no header or no `env:`.
    public static func headerEnvironment(_ content: String) -> [String: String] {
        guard let header = MaestroFlowParser.splitDocuments(content).config,
              let mapping = (try? Yams.load(yaml: header)) as? [String: Any],
              let env = mapping["env"] as? [String: Any] else { return [:] }
        return env.filter { isValidKey($0.key) }.compactMapValues { value in
            switch value {
            case is NSNull: return ""
            case let string as String: return string
            case let bool as Bool: return bool ? "true" : "false"
            case is [Any], is [String: Any]: return nil
            default: return "\(value)"
            }
        }
    }

    /// Launch keys are `[A-Za-z_][A-Za-z0-9_.]*`. On Android the runner can
    /// fall back to `am start` through a shell, interpolating the bare key, so
    /// anything else is refused rather than passed through.
    public static func isValidKey(_ key: String) -> Bool {
        key.range(of: "^[A-Za-z_][A-Za-z0-9_.]*$", options: .regularExpression) != nil
    }

    /// Parses `KEY=VALUE` arguments. The value may be empty and may itself
    /// contain `=`; the key may not be empty or contain whitespace.
    public static func parse(_ arguments: [String]) throws -> [String: String] {
        var environment: [String: String] = [:]
        for argument in arguments {
            guard let separator = argument.firstIndex(of: "=") else {
                throw GrantivaError.invalidArgument(
                    "Invalid --env \"\(argument)\": expected KEY=VALUE."
                )
            }
            let key = String(argument[argument.startIndex..<separator])
            let value = String(argument[argument.index(after: separator)...])
            guard !key.isEmpty else {
                throw GrantivaError.invalidArgument(
                    "Invalid --env \"\(argument)\": the key before `=` is empty."
                )
            }
            guard key.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
                throw GrantivaError.invalidArgument(
                    "Invalid --env \"\(argument)\": the key must not contain whitespace."
                )
            }
            guard isValidKey(key) else {
                throw GrantivaError.invalidArgument(
                    "Invalid --env \"\(argument)\": the key must start with a letter or `_` and contain only letters, digits, `_` and `.`."
                )
            }
            environment[key] = value
        }
        return environment
    }

    /// Injects `environment` into every `launchApp` step of a Maestro flow.
    /// Returns the rewritten YAML and whether any `launchApp` step was found —
    /// a flow with none cannot receive launch environment at all, which is
    /// worth telling the user about rather than silently doing nothing.
    ///
    /// `field` is the `launchApp` key the values go under (see
    /// `launchField(for:)`). With `overrideExisting` false, keys the step
    /// already declares keep their value.
    public static func inject(
        _ content: String,
        environment: [String: String],
        field: String = "environment",
        overrideExisting: Bool = true
    ) -> (yaml: String, injected: Bool) {
        guard !environment.isEmpty else { return (content, true) }

        let lines = content.components(separatedBy: "\n")
        var output: [String] = []
        var injected = false
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard let step = LaunchAppStep(line: line) else {
                output.append(line)
                index += 1
                continue
            }

            injected = true
            let itemIndent = String(repeating: " ", count: step.indent)
            let keyIndent = itemIndent + "    "

            switch step.form {
            case .bare:
                output.append("\(itemIndent)- launchApp:")
                output.append(contentsOf: environmentLines(environment, field: field, indent: keyIndent))
                index += 1

            case .scalar(let appId):
                output.append("\(itemIndent)- launchApp:")
                output.append("\(keyIndent)appId: \(appId)")
                output.append(contentsOf: environmentLines(environment, field: field, indent: keyIndent))
                index += 1

            case .mapping:
                output.append(line)
                index += 1
                // Copy the step's own mapping block, merging into an existing
                // `environment:` (or `field:`) if the flow already declares one.
                var blockIndent: Int?
                var mergedIntoExisting = false
                var existingEnvironmentIndent: Int?
                while index < lines.count {
                    let bodyLine = lines[index]
                    let trimmed = bodyLine.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        output.append(bodyLine)
                        index += 1
                        continue
                    }
                    let indent = bodyLine.prefix { $0 == " " }.count
                    guard indent > step.indent else { break }
                    if blockIndent == nil { blockIndent = indent }
                    index += 1

                    if let environmentIndent = existingEnvironmentIndent {
                        if indent > environmentIndent {
                            // Drop a pre-existing entry that --env overrides, so
                            // the merged mapping has no duplicate keys.
                            let key = trimmed.split(separator: ":", maxSplits: 1)
                                .first
                                .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) }
                            if overrideExisting, let key, environment[key] != nil { continue }
                        } else {
                            existingEnvironmentIndent = nil
                        }
                    }

                    output.append(bodyLine)
                    if trimmed == "\(field):" && indent == blockIndent {
                        var entries = environment
                        if !overrideExisting {
                            for key in existingKeys(in: lines, after: index, deeperThan: indent) {
                                entries[key] = nil
                            }
                        }
                        output.append(contentsOf: environmentEntries(
                            entries,
                            indent: String(repeating: " ", count: indent + 2)
                        ))
                        mergedIntoExisting = true
                        existingEnvironmentIndent = indent
                    }
                }
                if !mergedIntoExisting {
                    let indent = String(repeating: " ", count: blockIndent ?? (step.indent + 4))
                    output.append(contentsOf: environmentLines(environment, field: field, indent: indent))
                }
            }
        }

        return (output.joined(separator: "\n"), injected)
    }

    private static func environmentLines(_ environment: [String: String], field: String, indent: String) -> [String] {
        ["\(indent)\(field):"] + environmentEntries(environment, indent: indent + "  ")
    }

    /// Keys of the mapping block that starts at `lines[start]` and is indented
    /// deeper than `indent`.
    private static func existingKeys(in lines: [String], after start: Int, deeperThan indent: Int) -> [String] {
        var keys: [String] = []
        var index = start
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            index += 1
            if trimmed.isEmpty { continue }
            guard lines[index - 1].prefix(while: { $0 == " " }).count > indent else { break }
            if let key = trimmed.split(separator: ":", maxSplits: 1).first {
                keys.append(String(key).trimmingCharacters(in: CharacterSet(charactersIn: " \"'")))
            }
        }
        return keys
    }

    /// Renames `from:` to `to:` in each block-mapping `launchApp` step. When
    /// the step already declares `to:` as well, the entries of a block-style
    /// `from:` are moved into it instead (a key `to:` already has keeps its value).
    static func renameLaunchField(in content: String, from: String, to: String) -> String {
        var lines = content.components(separatedBy: "\n")
        func indentOf(_ line: String) -> Int { line.prefix { $0 == " " }.count }
        var index = 0
        while index < lines.count {
            guard let step = LaunchAppStep(line: lines[index]), case .mapping = step.form else {
                index += 1
                continue
            }
            let stepLine = index
            index += 1
            var blockIndent: Int?
            var fromLine: Int?
            var targetLine: Int?
            while index < lines.count {
                let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { index += 1; continue }
                let indent = indentOf(lines[index])
                guard indent > step.indent else { break }
                if blockIndent == nil { blockIndent = indent }
                if indent == blockIndent {
                    if trimmed.hasPrefix("\(from):") { fromLine = index }
                    if trimmed.hasPrefix("\(to):") { targetLine = index }
                }
                index += 1
            }
            guard let fromLine, let blockIndent else { continue }
            guard let targetLine else {
                lines[fromLine] = lines[fromLine].replacingOccurrences(
                    of: "\(from):", with: "\(to):", options: [], range: lines[fromLine].range(of: "\(from):")
                )
                continue
            }
            // Both present: only block-style mappings can be merged.
            guard lines[fromLine].trimmingCharacters(in: .whitespaces) == "\(from):",
                  lines[targetLine].trimmingCharacters(in: .whitespaces) == "\(to):" else { continue }
            var end = fromLine + 1
            while end < lines.count {
                let trimmed = lines[end].trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, indentOf(lines[end]) <= blockIndent { break }
                end += 1
            }
            let body = lines[(fromLine + 1)..<end].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let sourceIndent = body.map(indentOf).min() ?? (blockIndent + 2)
            let targetIndent = lines.indices.dropFirst(targetLine + 1)
                .first { !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty }
                .map { indentOf(lines[$0]) }
                .flatMap { $0 > blockIndent ? $0 : nil } ?? (blockIndent + 2)
            let taken = Set(existingKeys(in: lines, after: targetLine + 1, deeperThan: blockIndent))
            var moved: [String] = []
            var skipping = false
            for line in body {
                let indent = indentOf(line)
                if indent == sourceIndent {
                    let key = line.trimmingCharacters(in: .whitespaces).split(separator: ":", maxSplits: 1).first
                        .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: " \"'")) } ?? ""
                    skipping = taken.contains(key)
                }
                if !skipping {
                    moved.append(String(repeating: " ", count: targetIndent + indent - sourceIndent) + line.drop { $0 == " " })
                }
            }
            lines.removeSubrange(fromLine..<end)
            let insertAt = targetLine > fromLine ? targetLine - (end - fromLine) + 1 : targetLine + 1
            lines.insert(contentsOf: moved, at: insertAt)
            index = stepLine + 1
        }
        return lines.joined(separator: "\n")
    }

    private static func environmentEntries(_ environment: [String: String], indent: String) -> [String] {
        environment.keys.sorted().map { key in
            "\(indent)\(key): \(quoted(environment[key] ?? ""))"
        }
    }

    static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    /// A recognized `- launchApp` line and the YAML shape it uses.
    private struct LaunchAppStep {
        enum Form {
            case bare
            case scalar(String)
            case mapping
        }

        let indent: Int
        let form: Form

        init?(line: String) {
            let indent = line.prefix { $0 == " " }.count
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- launchApp") else { return nil }
            let remainder = trimmed.dropFirst("- launchApp".count)
            if remainder.isEmpty {
                self.indent = indent
                self.form = .bare
            } else if remainder.hasPrefix(":") {
                let value = remainder.dropFirst().trimmingCharacters(in: .whitespaces)
                if value.isEmpty {
                    self.indent = indent
                    self.form = .mapping
                } else if value.hasPrefix("{") {
                    // Inline mapping — leave it alone rather than risk mangling it.
                    return nil
                } else {
                    self.indent = indent
                    self.form = .scalar(value)
                }
            } else {
                return nil
            }
        }
    }
}
