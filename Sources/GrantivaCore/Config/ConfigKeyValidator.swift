import Foundation
import Yams

/// Finds keys in a `grantiva.yml` / `grantiva-android.yml` document that the
/// decoder would silently drop, so a typo like `schem:` or `screen:` is
/// reported instead of surfacing later as an unrelated error.
enum ConfigKeyValidator {
    static func unknownKeyWarnings(in root: Node, platform: Platform, fileName: String) -> [String] {
        var top = GrantivaConfig.CodingKeys.allCases.map(\.rawValue)
        if platform == .android {
            top += AndroidProject.CodingKeys.allCases.map(\.rawValue)
        }
        var warnings: [Warning] = []
        check(root, known: top, fileName: fileName, into: &warnings)
        guard let mapping = root.mapping else { return sorted(warnings) }

        if let diff = mapping["diff"] {
            check(diff, known: GrantivaConfig.DiffConfig.CodingKeys.allCases.map(\.rawValue), fileName: fileName, into: &warnings)
        }
        if let a11y = mapping["a11y"] {
            check(a11y, known: ["rules"], fileName: fileName, into: &warnings)
        }
        for screen in mapping["screens"]?.sequence ?? [] {
            check(screen, known: ["name", "path"], fileName: fileName, into: &warnings)
            for step in screen.mapping?["path"]?.sequence ?? [] {
                let stepKeys = GrantivaConfig.Screen.Step.CodingKeys.allCases
                check(step, known: stepKeys.map(\.rawValue), fileName: fileName, into: &warnings)
                for key in [GrantivaConfig.Screen.Step.CodingKeys.tap, .assertVisible, .assertNotVisible] {
                    if let label = step.mapping?[key.rawValue], label.mapping != nil {
                        let labelKeys = GrantivaConfig.Screen.Step.Label.CodingKeys.allCases.map(\.rawValue)
                        check(label, known: labelKeys, fileName: fileName, into: &warnings)
                    }
                }
            }
        }
        return sorted(warnings)
    }

    private struct Warning {
        var line: Int
        var message: String
    }

    /// In file order, so the output reads top to bottom.
    private static func sorted(_ warnings: [Warning]) -> [String] {
        warnings.enumerated()
            .sorted { ($0.element.line, $0.offset) < ($1.element.line, $1.offset) }
            .map(\.element.message)
    }

    private static func check(_ node: Node, known: [String], fileName: String, into warnings: inout [Warning]) {
        guard let mapping = node.mapping else { return }
        for (keyNode, _) in mapping {
            guard let key = keyNode.string, !known.contains(key) else { continue }
            let line = keyNode.mark.map { ":\($0.line)" } ?? ""
            var message = "\(fileName)\(line): unknown key \"\(key)\""
            if let suggestion = suggestion(for: key, among: known) {
                message += " (did you mean \"\(suggestion)\"?)"
            }
            warnings.append(Warning(line: keyNode.mark?.line ?? 0, message: message))
        }
    }

    /// The closest known key within two edits, if any.
    static func suggestion(for key: String, among known: [String]) -> String? {
        known
            .map { ($0, editDistance(key.lowercased(), $0)) }
            .filter { $0.1 <= 2 }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
