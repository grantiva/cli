import Foundation
import Yams

/// Rewrites `runFlow` references before a flow is moved to a temporary directory.
/// Maestro resolves relative references from the containing flow, so staging a
/// flow without doing this would silently change what its paths mean.
/// Every command it walks is also passed through `FlowNormalizer`.
enum FlowReferenceResolver {
    /// `mapFile`, when given, receives each resolved absolute `runFlow` path
    /// and returns the path to reference instead (for example a staged,
    /// rewritten copy of that file).
    static func resolve(
        in content: String,
        relativeTo baseDirectory: String,
        mapFile: ((String) throws -> String)? = nil
    ) throws -> String {
        var ignored: [String: String] = [:]
        return try resolve(in: content, relativeTo: baseDirectory, mapFile: mapFile, asWritten: &ignored)
    }

    /// As `resolve`, also reporting every `runFlow` path it rewrote: the
    /// path the runner will see (and print) mapped to the path as written in
    /// the flow, so output and reports can name the sub-flow the user's way.
    static func resolve(
        in content: String,
        relativeTo baseDirectory: String,
        mapFile: ((String) throws -> String)? = nil,
        asWritten: inout [String: String]
    ) throws -> String {
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
        let headerAppId = documents.config
            .flatMap { try? Yams.load(yaml: $0) as? [String: Any] }?["appId"] as? String
        let walker = Walker(baseDirectory: baseDirectory, headerAppId: headerAppId, mapFile: mapFile)
        let rewritten = try walker.rewriteCommands(commandList)
        asWritten.merge(walker.asWritten) { _, new in new }
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

    private final class Walker {
        let baseDirectory: String
        let headerAppId: String?
        let mapFile: ((String) throws -> String)?
        var asWritten: [String: String] = [:]

        init(baseDirectory: String, headerAppId: String?, mapFile: ((String) throws -> String)?) {
            self.baseDirectory = baseDirectory
            self.headerAppId = headerAppId
            self.mapFile = mapFile
        }

        func rewriteCommands(_ commands: [Any]) throws -> [Any] {
            try commands.map { command in
                let command = FlowNormalizer.normalize(command, headerAppId: headerAppId)
                guard var dictionary = command as? [String: Any] else { return command }
                if let runFlow = dictionary["runFlow"] {
                    dictionary["runFlow"] = try rewriteRunFlow(runFlow)
                }
                dictionary = try rewriteNestedCommandLists(dictionary)
                return dictionary
            }
        }

        /// Maestro control-flow commands can contain further command lists. Only
        /// values under a `commands` key are command syntax; arbitrary dictionaries
        /// such as launch environment values may legitimately use a `runFlow` key.
        private func rewriteNestedValue(_ value: Any) throws -> Any {
            if let values = value as? [Any] {
                return try values.map { try rewriteNestedValue($0) }
            }
            guard let dictionary = value as? [String: Any] else { return value }
            return try rewriteNestedCommandLists(dictionary)
        }

        private func rewriteNestedCommandLists(_ dictionary: [String: Any]) throws -> [String: Any] {
            var result: [String: Any] = [:]
            for (key, child) in dictionary {
                if key == "commands", let commands = child as? [Any] {
                    result[key] = try rewriteCommands(commands)
                } else {
                    result[key] = try rewriteNestedValue(child)
                }
            }
            return result
        }

        /// `runFlow: path`, `runFlow: {file: path, ...}`, or an inline
        /// `runFlow: {commands: [...], ...}`. Inline commands are walked by
        /// `rewriteNestedCommandLists`, so their own `runFlow`s are resolved
        /// against this flow's directory too.
        private func rewriteRunFlow(_ value: Any) throws -> Any {
            func resolved(_ path: String) throws -> String {
                let absolute = try FlowReferenceResolver.resolvePath(path, baseDirectory: baseDirectory)
                let target = try mapFile?(absolute) ?? absolute
                if target != path { asWritten[target] = path }
                return target
            }
            if let path = value as? String {
                return try resolved(path)
            }
            if var options = value as? [String: Any] {
                if let file = options["file"] as? String {
                    options["file"] = try resolved(file)
                    return options
                }
                if options["file"] == nil, options["commands"] is [Any] {
                    return options
                }
                throw FlowReferenceResolver.invalidRunFlow(
                    "use `runFlow: <file>`, `runFlow: {file: <file>}`, or inline `runFlow: {commands: [...]}`"
                )
            }
            throw FlowReferenceResolver.invalidRunFlow(
                "use `runFlow: <file>`, `runFlow: {file: <file>}`, or inline `runFlow: {commands: [...]}`"
            )
        }
    }

    static func resolvePath(_ path: String, baseDirectory: String) throws -> String {
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw invalidRunFlow("path must not be empty")
        }
        guard !NSString(string: path).isAbsolutePath else { return path }
        return URL(fileURLWithPath: baseDirectory, isDirectory: true)
            .appendingPathComponent(path)
            .standardizedFileURL.path
    }

    static func invalidRunFlow(_ reason: String) -> GrantivaError {
        .invalidArgument("Invalid runFlow command: \(reason)")
    }
}
