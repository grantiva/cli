import Foundation

/// Rewrites the staged flow paths the runner recorded in a preserved
/// `--report-dir` back into the paths the user passed.
///
/// The runner writes `report.json`, `flows/*.json`, `junit-report.xml` and
/// `maestro-runner.log` against the temp copies grantiva staged, which are
/// deleted when the run ends. CI uploads these files, so they must name the
/// user's flow files. Each format gets its own escaping so the files stay
/// valid JSON and XML.
enum RunnerReportRewriter {
    static func rewrite(reportDir: String, stagedPathMap: [String: String]) {
        let map = expanded(stagedPathMap)
        guard !map.isEmpty else { return }
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: reportDir, isDirectory: true)

        var jsonFiles = [root.appendingPathComponent("report.json")]
        let flowsDir = root.appendingPathComponent("flows", isDirectory: true)
        let flowFiles = (try? fileManager.contentsOfDirectory(atPath: flowsDir.path)) ?? []
        jsonFiles += flowFiles.filter { $0.hasSuffix(".json") }.sorted().map { flowsDir.appendingPathComponent($0) }

        for file in jsonFiles {
            rewriteFile(at: file) { rewriteJSON($0, map: map) }
        }
        rewriteFile(at: root.appendingPathComponent("junit-report.xml")) { rewriteXML($0, map: map) }
        rewriteFile(at: root.appendingPathComponent("maestro-runner.log")) {
            OutputRewriter(replacements: map).rewrite($0)
        }
    }

    /// Replaces each staged path where it appears inside a JSON string
    /// literal, writing the user path with JSON escaping. Text-level so the
    /// runner's key order and formatting are kept.
    static func rewriteJSON(_ text: String, map: [String: String]) -> String {
        var replacements: [String: String] = [:]
        for (source, target) in map {
            let escapedTarget = jsonEscaped(target)
            for variant in jsonEncodings(of: source) {
                replacements[variant] = escapedTarget
            }
        }
        return OutputRewriter(replacements: replacements).rewrite(text)
    }

    /// Replaces each staged path where it appears in XML text or attribute
    /// values, writing the user path with XML escaping.
    static func rewriteXML(_ text: String, map: [String: String]) -> String {
        var replacements: [String: String] = [:]
        for (source, target) in map {
            let escapedTarget = xmlEscaped(target)
            // Go's encoding/xml writes quotes as numeric references.
            let goSource = xmlEscaped(source)
                .replacingOccurrences(of: "&quot;", with: "&#34;")
                .replacingOccurrences(of: "&apos;", with: "&#39;")
            replacements[xmlEscaped(source)] = escapedTarget
            replacements[goSource] = escapedTarget
        }
        return OutputRewriter(replacements: replacements).rewrite(text)
    }

    /// `/var/folders/...` is `/private/var/folders/...` once resolved; the
    /// runner may record either spelling.
    static func expanded(_ map: [String: String]) -> [String: String] {
        var result = map
        for (source, target) in map {
            if source.hasPrefix("/private/") {
                result[String(source.dropFirst("/private".count))] = target
            } else if source.hasPrefix("/var/") || source.hasPrefix("/tmp/") {
                result["/private" + source] = target
            }
        }
        return result
    }

    private static func rewriteFile(at url: URL, transform: (String) -> String) {
        guard let data = FileManager.default.contents(atPath: url.path),
              let text = String(data: data, encoding: .utf8) else { return }
        let rewritten = transform(text)
        guard rewritten != text else { return }
        do {
            try Data(rewritten.utf8).write(to: url, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data(
                "[grantiva] could not rewrite flow paths in \(url.lastPathComponent): \(error.localizedDescription)\n".utf8
            ))
        }
    }

    /// The runner is Go: it may escape `/` (it does not by default) and
    /// escapes `<`, `>` and `&` as `<`, `>`, `&`.
    private static func jsonEncodings(of value: String) -> Set<String> {
        let plain = jsonEscaped(value)
        let slashes = plain.replacingOccurrences(of: "/", with: "\\/")
        let go = plain
            .replacingOccurrences(of: "&", with: "\\u0026")
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
        return [plain, slashes, go]
    }

    static func jsonEscaped(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(
            withJSONObject: [value], options: [.withoutEscapingSlashes, .fragmentsAllowed]
        ), let encoded = String(data: data, encoding: .utf8) else { return value }
        // ["…"] -> …
        return String(encoded.dropFirst(2).dropLast(2))
    }

    static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
