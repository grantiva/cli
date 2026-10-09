import Foundation

/// The xcconfig the CLI hands xcodebuild through `XCODE_XCCONFIG_FILE` when
/// the runner builds WebDriverAgent.
///
/// WDA compiles with `-Weverything` and warnings-as-errors. Xcode 27's clang
/// adds `-Wpoison-system-directories`, which fires on clang's own implicit
/// `/usr/local/include` search path, so every WDA build ends in
/// `** TEST BUILD FAILED **`. Suppressing that one warning keeps the rest of
/// WDA's warning policy intact. `$(inherited)` keeps the project's flags.
public enum WDABuildConfig {
    public static let fileName = "grantiva-wda.xcconfig"

    public static let contents = """
    // Written by grantiva. xcodebuild reads this through XCODE_XCCONFIG_FILE
    // when the runner builds WebDriverAgent. Edits are overwritten.
    WARNING_CFLAGS = $(inherited) -Wno-poison-system-directories

    """

    /// Writes the xcconfig into `runnerHome` when it is missing or stale and
    /// returns its path. Returns nil when the file cannot be written, so the
    /// caller can fall back to the runner's stock build.
    public static func install(in runnerHome: String, fileManager: FileManager = .default) -> String? {
        let path = (runnerHome as NSString).appendingPathComponent(fileName)
        let wanted = Data(contents.utf8)
        if fileManager.contents(atPath: path) == wanted { return path }
        guard fileManager.createFile(atPath: path, contents: wanted) else { return nil }
        return path
    }
}
