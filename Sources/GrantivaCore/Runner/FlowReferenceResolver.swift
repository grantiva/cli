import Foundation
import Yams

/// Rewrites `runFlow` references before a flow is moved to a temporary directory.
/// Maestro resolves relative references from the containing flow, so staging a
/// flow without doing this would silently change what its paths mean.
enum FlowReferenceResolver {
    static func resolve(in content: String, relativeTo baseDirectory: String) throws -> String {
        let documents = MaestroFlowParser.splitDocuments(content)
        guard let commands = documents.commands else { return content }

        let loaded: Any
        do {
            guard let value = try Yams.load(yaml: commands) else { return content }
            loaded = value
        } catch {
            throw GrantivaError.invalidArgument("Could not parse flow commands: \(error.localizedDescription)")
        }

        guard let commandList = loaded as? [Any] else {
            throw GrantivaError.invalidArgument("Flow commands must be a YAML list")
        }
        let rewritten = try rewriteCommands(commandList, baseDirectory: baseDirectory)
        let emitted: String
        do {
            emitted = try Yams.dump(object: rewritten)
        } catch {
            throw GrantivaError.invalidArgument("Could not stage flow commands: \(error.localizedDescription)")
        }

        if let config = documents.config {
            return config + "\n---\n" + emitted
        }
        return emitted
    }

    private static func rewriteCommands(
        _ commands: [Any], baseDirectory: String
    ) throws -> [Any] {
        try commands.map { command in
            guard var dictionary = command as? [String: Any] else { return command }
            if let runFlow = dictionary["runFlow"] {
                dictionary["runFlow"] = try rewriteRunFlow(
                    runFlow, baseDirectory: baseDirectory
                )
            }
            dictionary = try rewriteNestedCommandLists(
                dictionary, baseDirectory: baseDirectory
            )
            return dictionary
        }
    }

    /// Maestro control-flow commands can contain further command lists. Only
    /// values under a `commands` key are command syntax; arbitrary dictionaries
    /// such as launch environment values may legitimately use a `runFlow` key.
    private static func rewriteNestedValue(_ value: Any, baseDirectory: String) throws -> Any {
        if let values = value as? [Any] {
            return try values.map {
                try rewriteNestedValue($0, baseDirectory: baseDirectory)
            }
        }
        guard let dictionary = value as? [String: Any] else { return value }
        return try rewriteNestedCommandLists(dictionary, baseDirectory: baseDirectory)
    }

    private static func rewriteNestedCommandLists(
        _ dictionary: [String: Any], baseDirectory: String
    ) throws -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, child) in dictionary {
            if key == "commands", let commands = child as? [Any] {
                result[key] = try rewriteCommands(commands, baseDirectory: baseDirectory)
            } else {
                result[key] = try rewriteNestedValue(
                    child, baseDirectory: baseDirectory
                )
            }
        }
        return result
    }

    private static func rewriteRunFlow(_ value: Any, baseDirectory: String) throws -> Any {
        if let path = value as? String {
            return try resolvePath(path, baseDirectory: baseDirectory)
        }
        if var options = value as? [String: Any] {
            guard let file = options["file"] as? String else {
                throw invalidRunFlow("object form requires a string 'file' field")
            }
            options["file"] = try resolvePath(file, baseDirectory: baseDirectory)
            return options
        }
        throw invalidRunFlow("expected a path string or an object with a string 'file' field")
    }

    private static func resolvePath(_ path: String, baseDirectory: String) throws -> String {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw invalidRunFlow("path must not be empty")
        }
        guard !NSString(string: path).isAbsolutePath else { return path }
        return URL(fileURLWithPath: baseDirectory, isDirectory: true)
            .appendingPathComponent(path)
            .standardizedFileURL.path
    }

    private static func invalidRunFlow(_ reason: String) -> GrantivaError {
        .invalidArgument("Invalid runFlow command: \(reason)")
    }
}
