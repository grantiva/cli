import Foundation

/// The runner's per-step trace shots (`cmd-NNN-before.png`,
/// `cmd-NNN-after.png`, hierarchy XML) and the `--snapshot trailing` rule.
///
/// `trailing` asks the runner for every step (`--artifacts always`), so the
/// report directory receives the same set `full` writes. With `--report-dir`
/// that directory is what the user keeps, so it is trimmed to the trailing
/// set too: the last good step's `after` shot and the failing (last) step's
/// shots. Named `takeScreenshot` captures are never trace shots and stay.
enum RunnerTraceTrimmer {
    struct StepShot: Equatable {
        let index: Int
        /// `before`, `after`, or `xml`.
        let kind: String
    }

    /// `cmd-NNN-before.png` / `cmd-NNN-after.png` / `cmd-NNN-*.xml`; nil for
    /// anything else, including a named screenshot `cmd-NNN-<name>.png`.
    static func stepShot(_ name: String) -> StepShot? {
        guard name.hasPrefix("cmd-") else { return nil }
        let parts = name.dropFirst(4).split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2, let index = Int(parts[0]) else { return nil }
        switch parts[1].lowercased() {
        case "before.png": return StepShot(index: index, kind: "before")
        case "after.png": return StepShot(index: index, kind: "after")
        default:
            return parts[1].lowercased().hasSuffix(".xml") ? StepShot(index: index, kind: "xml") : nil
        }
    }

    /// True for a file the runner wrote as a per-step trace shot.
    static func isStepShot(_ name: String) -> Bool { stepShot(name) != nil }

    /// The step shots `trailing` keeps out of `names`: every shot of the last
    /// step and the `after` shot of the step before it.
    static func trailingKeep(_ names: [String]) -> Set<String> {
        let indexed = names.compactMap { name -> (String, Int)? in
            guard name.hasPrefix("cmd-"),
                  let index = Int(name.dropFirst(4).split(separator: "-", maxSplits: 1).first ?? "") else { return nil }
            return (name, index)
        }
        guard let last = indexed.map(\.1).max() else { return [] }
        return Set(indexed.compactMap { name, index in
            if index == last { return name }
            if index == last - 1, stepShot(name)?.kind == "after" { return name }
            return nil
        })
    }

    /// Deletes the step shots `trailing` does not keep from every flow's
    /// assets in `reportDir`, the matching Allure attachments, and every
    /// reference to them. Best-effort.
    static func trimTrailing(reportDir: String) {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: reportDir, isDirectory: true)
        guard let report = RunnerReportFinalizer.readJSON(root.appendingPathComponent("report.json")) else { return }

        var removedPaths: Set<String> = []
        var removedContents: Set<Data> = []
        for flow in report["flows"] as? [[String: Any]] ?? [] {
            guard let assetsDir = flow["assetsDir"] as? String, !assetsDir.contains("..") else { continue }
            let assets = root.appendingPathComponent(assetsDir, isDirectory: true)
            let names = ((try? fileManager.contentsOfDirectory(atPath: assets.path)) ?? []).sorted()
            let keep = trailingKeep(names)
            for name in names where isStepShot(name) && !keep.contains(name) {
                let url = assets.appendingPathComponent(name)
                if let data = fileManager.contents(atPath: url.path) { removedContents.insert(data) }
                if (try? fileManager.removeItem(at: url)) != nil {
                    removedPaths.insert("\(assetsDir)/\(name)")
                }
            }
            if let dataFile = flow["dataFile"] as? String, !dataFile.contains("..") {
                dropReferences(to: removedPaths, inFlowData: root.appendingPathComponent(dataFile))
            }
        }
        guard !removedContents.isEmpty else { return }
        trimAllure(in: root.appendingPathComponent("allure-results", isDirectory: true), removing: removedContents)
    }

    private static func dropReferences(to removed: Set<String>, inFlowData url: URL) {
        guard !removed.isEmpty, var data = RunnerReportFinalizer.readJSON(url) else { return }
        var commands = data["commands"] as? [[String: Any]] ?? []
        var changed = false
        for index in commands.indices {
            guard var artifacts = commands[index]["artifacts"] as? [String: Any] else { continue }
            for (key, value) in artifacts where (value as? String).map(removed.contains) == true {
                artifacts.removeValue(forKey: key)
                changed = true
            }
            commands[index]["artifacts"] = artifacts
        }
        guard changed else { return }
        data["commands"] = commands
        RunnerReportFinalizer.writeJSON(data, to: url)
    }

    /// Allure copies each shot to `<hash>-attachment.png`; the copies of the
    /// removed shots go, and so do the result entries that name them.
    private static func trimAllure(in directory: URL, removing contents: Set<Data>) {
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        var removedSources: Set<String> = []
        for name in names where name.hasSuffix("-attachment.png") {
            let url = directory.appendingPathComponent(name)
            guard let data = fileManager.contents(atPath: url.path), contents.contains(data) else { continue }
            if (try? fileManager.removeItem(at: url)) != nil { removedSources.insert(name) }
        }
        guard !removedSources.isEmpty else { return }
        for name in names where name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let object = RunnerReportFinalizer.readJSON(url) else { continue }
            let pruned = pruneAttachments(object, removing: removedSources)
            if let pruned = pruned as? [String: Any], !NSDictionary(dictionary: pruned).isEqual(to: object) {
                RunnerReportFinalizer.writeJSON(pruned, to: url)
            }
        }
    }

    private static func pruneAttachments(_ value: Any, removing sources: Set<String>) -> Any {
        if var dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if key == "attachments", let list = child as? [[String: Any]] {
                    dictionary[key] = list.filter { !sources.contains($0["source"] as? String ?? "") }
                        .map { pruneAttachments($0, removing: sources) }
                } else {
                    dictionary[key] = pruneAttachments(child, removing: sources)
                }
            }
            return dictionary
        }
        if let list = value as? [Any] {
            return list.map { pruneAttachments($0, removing: sources) }
        }
        return value
    }
}
