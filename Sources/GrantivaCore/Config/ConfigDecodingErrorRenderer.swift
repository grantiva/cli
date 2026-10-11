import Foundation
import Yams

/// Turns a config `DecodingError` into plain config errors (L42-b):
/// `<file>:<line>: <path>: <what is wrong and what the key takes>`, one per
/// bad step, with that step's unknown keys folded in. No Swift type names,
/// coding keys or debug descriptions reach the user.
enum ConfigDecodingErrorRenderer {
    typealias Step = GrantivaConfig.Screen.Step

    /// `decodeOutsideScreens` decodes a document (the file without its
    /// `screens:`), so an error elsewhere is reported next to the steps'.
    static func message(
        for error: Error, root: Node?, fileName: String, unknownKeys: [ConfigKeyValidator.Warning],
        decodeOutsideScreens: ((Node) throws -> Void)? = nil
    ) -> String {
        var lines: [String] = []
        var folded = Set<Int>()
        // Each screen step is decoded on its own, so every bad step is named,
        // not only the first one the decoder met.
        if let root {
            for (screenIndex, screen) in (root.mapping?["screens"]?.sequence ?? []).enumerated() {
                for (stepIndex, step) in (screen.mapping?["path"]?.sequence ?? []).enumerated() {
                    do {
                        _ = try YAMLDecoder().decode(Step.self, from: step)
                    } catch let stepError as DecodingError {
                        let base: [PathKey] = [.key("screens"), .index(screenIndex), .key("path"), .index(stepIndex)]
                        let rendered = render(stepError, base: base, node: step, fileName: fileName)
                        let stepLines = Set(keyLines(in: step))
                        let mine = unknownKeys.filter { stepLines.contains($0.line) }
                        folded.formUnion(mine.map(\.line))
                        lines.append(([rendered] + mine.map(\.detail)).joined(separator: "; ") + ".")
                    } catch {
                        continue
                    }
                }
            }
        }
        if !lines.isEmpty, let decodeOutsideScreens, let mapping = root?.mapping {
            // The decoder stopped at the first bad step; an error outside
            // `screens:` (under `diff:`, say) is reported too.
            let rest = Node.mapping(Node.Mapping(
                mapping.filter { $0.key.string != "screens" }, mapping.tag, mapping.style, mapping.mark
            ))
            do {
                try decodeOutsideScreens(rest)
            } catch let decoding as DecodingError {
                lines.append(render(decoding, base: [], node: rest, fileName: fileName) + ".")
            } catch {}
        }
        if lines.isEmpty {
            if let decoding = error as? DecodingError, let root {
                lines.append(render(decoding, base: [], node: root, fileName: fileName) + ".")
            } else {
                lines.append("\(fileName) could not be parsed: \(error.localizedDescription)")
            }
        }
        lines += unknownKeys.filter { !folded.contains($0.line) }.map(\.message)
        return lines.joined(separator: "\n")
    }

    enum PathKey {
        case key(String)
        case index(Int)
    }

    /// `<file>:<line>: <path>: <problem>`, with the line of the deepest node
    /// the error's coding path reaches under `node`.
    static func render(_ error: DecodingError, base: [PathKey], node: Node, fileName: String) -> String {
        let codingPath: [CodingKey]
        let problem: (_ key: String?, _ value: Node?) -> String
        switch error {
        case .keyNotFound(let key, let context):
            codingPath = context.codingPath
            problem = { _, _ in "missing key \"\(key.stringValue)\"" }
        case .typeMismatch(let type, let context), .valueNotFound(let type, let context):
            codingPath = context.codingPath
            problem = { key, value in
                "\(key.map { "\($0) takes" } ?? "expected") \(phrase(for: type, key: key))"
                    + (value?.scalar.map { "; got \"\($0.string)\"" } ?? "")
            }
        case .dataCorrupted(let context):
            codingPath = context.codingPath
            let reason = context.debugDescription
            problem = { key, value in
                if let key, labelKeys.contains(key) {
                    if reason.hasPrefix("takes") { return "\(key) \(reason)" }
                    if reason.hasPrefix("`") { return reason }
                    return "\(key) takes \(Step.Label.acceptedForms)"
                }
                return (key.map { "\($0): " } ?? "") + "has a value grantiva cannot read"
                    + (value?.scalar.map { " (\"\($0.string)\")" } ?? "")
            }
        @unknown default:
            return "\(fileName): could not be read"
        }
        let path = base + codingPath.map { $0.intValue.map(PathKey.index) ?? .key($0.stringValue) }
        let (target, line) = resolve(codingPath, in: node)
        let lastKey = path.last.flatMap { if case .key(let key) = $0 { key } else { nil } }
        let lineText = line.map { ":\($0)" } ?? ""
        return "\(fileName)\(lineText): \(describe(path)): \(problem(lastKey, target))"
    }

    static let labelKeys: Set<String> = [
        Step.CodingKeys.tap.rawValue, Step.CodingKeys.assertVisible.rawValue, Step.CodingKeys.assertNotVisible.rawValue,
    ]

    /// What a key takes, in config terms.
    static func phrase(for type: Any.Type, key: String?) -> String {
        if key == Step.CodingKeys.wait.rawValue { return "a number of seconds" }
        if let key, labelKeys.contains(key) { return Step.Label.acceptedForms }
        let name = String(describing: type)
        switch name {
        case "Double", "Float": return "a number"
        case "Int", "UInt64", "Int64", "UInt32": return "a whole number"
        case "String": return "a string"
        case "Bool": return "true or false"
        default:
            if name.hasPrefix("Array") { return "a list" }
            if name.hasPrefix("Dictionary") { return "a mapping" }
            return "a different value"
        }
    }

    /// `screens[0].path[2].tap`
    static func describe(_ path: [PathKey]) -> String {
        path.enumerated().map { offset, key in
            switch key {
            case .key(let name): return offset == 0 ? name : ".\(name)"
            case .index(let index): return "[\(index)]"
            }
        }.joined()
    }

    /// The node the path reaches (as deep as it goes) and the line of its
    /// key, or of the node itself.
    static func resolve(_ path: [CodingKey], in node: Node) -> (Node?, Int?) {
        var current = node
        var line = node.mark?.line
        for key in path {
            if let index = key.intValue {
                guard let items = current.sequence, items.indices.contains(index) else { return (current, line) }
                current = items[index]
                line = current.mark?.line ?? line
            } else {
                guard let mapping = current.mapping,
                      let pair = mapping.first(where: { $0.key.string == key.stringValue }) else { return (current, line) }
                current = pair.value
                line = pair.key.mark?.line ?? line
            }
        }
        return (current, line)
    }

    /// The lines of every key in `node`'s subtree.
    static func keyLines(in node: Node) -> [Int] {
        if let mapping = node.mapping {
            return mapping.flatMap { pair in [pair.key.mark?.line].compactMap { $0 } + keyLines(in: pair.value) }
        }
        return (node.sequence ?? []).flatMap(keyLines(in:))
    }
}
