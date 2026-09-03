import Foundation

/// Prepares a runner report directory for a new invocation without treating
/// the caller-provided directory as disposable.
enum RunnerReportWorkspace {
    /// Files and directories written by grantiva-runner that can otherwise be
    /// mistaken for results from the next invocation.
    private static let staleEntries = ["report.json", "assets"]

    static func prepare(at path: String) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)

        for entry in staleEntries {
            let stalePath = (path as NSString).appendingPathComponent(entry)
            if fileManager.fileExists(atPath: stalePath) {
                try fileManager.removeItem(atPath: stalePath)
            }
        }
    }
}
