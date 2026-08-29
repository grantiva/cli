import Foundation

/// Parses `--env KEY=VALUE` pairs and injects them into a flow's `launchApp`
/// steps.
///
/// The runner already supports an `environment:` field on `launchApp` and
/// forwards it to the app at launch, so `--env` rides that existing path rather
/// than introducing a second mechanism. Injection happens on the staged copy of
/// the flow — the same copy that already receives the resolved `appId` — so the
/// user's file is never modified.
public enum FlowEnvironment {
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
            environment[key] = value
        }
        return environment
    }

    /// Injects `environment` into every `launchApp` step of a Maestro flow.
    /// Returns the rewritten YAML and whether any `launchApp` step was found —
    /// a flow with none cannot receive launch environment at all, which is
    /// worth telling the user about rather than silently doing nothing.
    public static func inject(
        _ content: String,
        environment: [String: String]
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
                output.append(contentsOf: environmentLines(environment, indent: keyIndent))
                index += 1

            case .scalar(let appId):
                output.append("\(itemIndent)- launchApp:")
                output.append("\(keyIndent)appId: \(appId)")
                output.append(contentsOf: environmentLines(environment, indent: keyIndent))
                index += 1

            case .mapping:
                output.append(line)
                index += 1
                // Copy the step's own mapping block, merging into an existing
                // `environment:` if the flow already declares one.
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
                                .map { String($0).trimmingCharacters(in: .whitespaces) }
                            if let key, environment[key] != nil { continue }
                        } else {
                            existingEnvironmentIndent = nil
                        }
                    }

                    output.append(bodyLine)
                    if trimmed == "environment:" && indent == blockIndent {
                        output.append(contentsOf: environmentEntries(
                            environment,
                            indent: String(repeating: " ", count: indent + 2)
                        ))
                        mergedIntoExisting = true
                        existingEnvironmentIndent = indent
                    }
                }
                if !mergedIntoExisting {
                    let indent = String(repeating: " ", count: blockIndent ?? (step.indent + 4))
                    output.append(contentsOf: environmentLines(environment, indent: indent))
                }
            }
        }

        return (output.joined(separator: "\n"), injected)
    }

    private static func environmentLines(_ environment: [String: String], indent: String) -> [String] {
        ["\(indent)environment:"] + environmentEntries(environment, indent: indent + "  ")
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
