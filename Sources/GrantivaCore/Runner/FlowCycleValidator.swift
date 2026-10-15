import Foundation
import Yams

/// Rejects file-backed flow cycles before runner or device setup begins.
public enum FlowCycleValidator {
    private struct Target {
        let nativePath: String
        let written: String
    }

    public static func validate(
        flowPaths: [String], screens: [GrantivaConfig.Screen],
        cwd: String = FileManager.default.currentDirectoryPath
    ) throws {
        for flow in flowPaths {
            let nativePath = lexical(flow)
            if let chain = cycle(startingAt: Target(nativePath: nativePath, written: flow), cwd: cwd) {
                throw GrantivaError.invalidArgument("circular dependency detected: \(chain.joined(separator: " -> "))")
            }
        }

        for screen in screens {
            guard case let .steps(steps) = screen.path else { continue }
            for step in steps {
                guard let operand = step.runFlow else { continue }
                let path = absolute(operand, relativeTo: cwd)
                if let chain = cycle(startingAt: Target(nativePath: path, written: operand), cwd: cwd) {
                    throw GrantivaError.invalidArgument(
                        "circular dependency detected: \((["grantiva.yml"] + chain).joined(separator: " -> "))"
                    )
                }
            }
        }
    }

    /// Follows the frozen native validator's lexical path identity and chain
    /// spelling, with a physical include-context guard for symlink aliases.
    private static func cycle(startingAt root: Target, cwd: String) -> [String]? {
        struct Node {
            let target: Target
            let safetyIdentity: String
        }
        var stack: [Node] = []
        var finished = Set<String>()

        func visit(_ target: Target) -> [String]? {
            let readPath = absolute(target.nativePath, relativeTo: cwd)
            let canonical = URL(fileURLWithPath: readPath).resolvingSymlinksInPath().path
            let parent = (readPath as NSString).deletingLastPathComponent
            let resolvedParent = URL(fileURLWithPath: parent).resolvingSymlinksInPath().path
            let safetyIdentity = canonical + "\u{0}" + resolvedParent

            if let index = stack.firstIndex(where: { $0.target.nativePath == target.nativePath }) {
                // Preserve the native validator's first spelling transition.
                // A relative CLI root first becomes an absolute child target;
                // an absolute CLI root first returns through the relative
                // operand written in its child. Both close on the following
                // hop, retaining the four-part diagnostic.
                let absoluteRootTransition = index == 0
                    && (stack[0].target.written as NSString).isAbsolutePath
                    && !(target.written as NSString).isAbsolutePath
                    && !stack.dropFirst().contains(where: { $0.target.nativePath == target.nativePath })
                if !absoluteRootTransition {
                    return stack.map { display($0.target, cwd: cwd) } + [display(target, cwd: cwd)]
                }
            }
            if let index = stack.firstIndex(where: { $0.safetyIdentity == safetyIdentity }) {
                // The native runner receives a relative top-level operand, then
                // absolute staged children. Let that one spelling transition
                // occur so its established a→b→a→b diagnostic is preserved.
                let relativeRootTransition = index == 0
                    && !(stack[0].target.nativePath as NSString).isAbsolutePath
                    && (target.nativePath as NSString).isAbsolutePath
                    && !stack.dropFirst().contains(where: { $0.safetyIdentity == safetyIdentity })
                let absoluteRootTransition = index == 0
                    && (stack[0].target.written as NSString).isAbsolutePath
                    && !(target.written as NSString).isAbsolutePath
                    && !stack.dropFirst().contains(where: { $0.safetyIdentity == safetyIdentity })
                if !relativeRootTransition && !absoluteRootTransition {
                    return stack.map { display($0.target, cwd: cwd) } + [display(target, cwd: cwd)]
                }
            }
            if finished.contains(target.nativePath) { return nil }
            guard let content = try? String(contentsOfFile: readPath, encoding: .utf8) else { return nil }

            stack.append(Node(target: target, safetyIdentity: safetyIdentity))
            defer {
                stack.removeLast()
                finished.insert(target.nativePath)
            }
            for child in references(in: content, relativeTo: (readPath as NSString).deletingLastPathComponent) {
                if let found = visit(child) { return found }
            }
            return nil
        }
        return visit(root)
    }

    /// Mirrors the frozen native validator: main commands and lifecycle hooks;
    /// runFlow file/commands; repeat commands; retry file/commands. Conditions
    /// and repeat counts do not suppress structural validation.
    private static func references(in content: String, relativeTo directory: String) -> [Target] {
        let documents = MaestroFlowParser.splitDocuments(content)
        var result: [Target] = []
        func appendFile(_ value: Any?) {
            guard let written = value as? String else { return }
            result.append(Target(nativePath: absolute(written, relativeTo: directory), written: written))
        }
        func walkSteps(_ value: Any) {
            guard let steps = value as? [Any] else { return }
            for step in steps {
                guard let dictionary = step as? [String: Any] else { continue }
                if let runFlow = dictionary["runFlow"] {
                    if let path = runFlow as? String {
                        appendFile(path)
                    } else if let options = runFlow as? [String: Any] {
                        appendFile(options["file"])
                        if let nested = options["commands"] { walkSteps(nested) }
                    }
                }
                if let repeatOptions = dictionary["repeat"] as? [String: Any],
                   let nested = repeatOptions["commands"] {
                    walkSteps(nested)
                }
                if let retryOptions = dictionary["retry"] as? [String: Any] {
                    appendFile(retryOptions["file"])
                    if let nested = retryOptions["commands"] { walkSteps(nested) }
                }
            }
        }
        if let commands = documents.commands, let loaded = try? Yams.load(yaml: commands) {
            walkSteps(loaded)
        }
        if let config = documents.config,
           let loaded = try? Yams.load(yaml: config) as? [String: Any] {
            if let onFlowStart = loaded["onFlowStart"] { walkSteps(onFlowStart) }
            if let onFlowComplete = loaded["onFlowComplete"] { walkSteps(onFlowComplete) }
        }
        return result
    }

    private static func lexical(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private static func absolute(_ path: String, relativeTo directory: String) -> String {
        if (path as NSString).isAbsolutePath { return lexical(path) }
        return lexical((directory as NSString).appendingPathComponent(path))
    }

    /// Native chainHop.display: project-contained paths are cwd-relative;
    /// outside paths retain the operand exactly as written.
    private static func display(_ target: Target, cwd: String) -> String {
        // An absolute CLI operand is itself part of the public diagnostic.
        // Its descendants retain the relative operands written in each file.
        if (target.written as NSString).isAbsolutePath { return target.written }
        let path = absolute(target.nativePath, relativeTo: cwd)
        let candidates = [
            (URL(fileURLWithPath: cwd).standardizedFileURL.path, URL(fileURLWithPath: path).standardizedFileURL.path),
            (URL(fileURLWithPath: cwd).resolvingSymlinksInPath().path, URL(fileURLWithPath: path).resolvingSymlinksInPath().path),
        ]
        for (base, candidate) in candidates {
            let prefix = base.hasSuffix("/") ? base : base + "/"
            if candidate == base { return "." }
            if candidate.hasPrefix(prefix) { return String(candidate.dropFirst(prefix.count)) }
        }
        return target.written
    }
}
