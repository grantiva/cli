import Foundation

public struct DoctorRunner: Sendable {
    public init() {}

    public func runAllChecks() async -> [DoctorCheck] {
        var checks: [DoctorCheck] = []

        // Required
        checks.append(await checkXcode())
        checks.append(await checkXcodeVersion())
        checks.append(await checkBootedSimulator())
        checks.append(await checkRunner())

        // Project
        checks.append(checkGrantivaConfig())
        checks.append(checkGitRepository())

        // CI / Cloud
        checks.append(checkGrantivaAuth())
        checks.append(checkGitHubApp())

        return checks
    }

    /// Whether the environment is broken enough that a caller should stop.
    ///
    /// `grantiva doctor || exit 1` is the intended CI preflight. Only `.error`
    /// counts: the optional checks (no booted simulator, no `grantiva.yml`, not
    /// authenticated) report `.warning` and are advisory, so they must not
    /// change the exit code.
    public static func hasFailures(_ checks: [DoctorCheck]) -> Bool {
        checks.contains { $0.status == .error }
    }

    /// `xcode-select -p` echoes `$DEVELOPER_DIR` back without checking it, so it
    /// succeeds and prints a path that does not exist. Reporting that as a
    /// passing toolchain is worse than reporting nothing: it is exactly the
    /// broken-CI-image case doctor exists to catch.
    func checkXcode() async -> DoctorCheck {
        let missing = DoctorCheck(
            name: "Xcode", status: .error,
            message: "Xcode not found",
            fix: "Install Xcode from the App Store and run: xcode-select --install"
        )
        guard let path = try? await shell("xcode-select -p"), !path.isEmpty else { return missing }
        guard FileManager.default.fileExists(atPath: path) else {
            return DoctorCheck(
                name: "Xcode", status: .error,
                message: "\(path) does not exist",
                fix: "Point at an installed Xcode: sudo xcode-select -s /Applications/Xcode.app (or unset DEVELOPER_DIR)"
            )
        }
        return DoctorCheck(name: "Xcode", status: .ok, message: path, fix: nil)
    }

    func checkXcodeVersion() async -> DoctorCheck {
        let unknown = DoctorCheck(
            name: "Xcode Version", status: .error,
            message: "Could not determine Xcode version",
            fix: "Ensure Xcode is properly installed"
        )
        // `head -1` of no output is an empty string and a zero exit status, so
        // success alone said nothing about whether a version was obtained.
        guard let version = try? await shell("xcodebuild -version | head -1"),
              !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return unknown }
        return DoctorCheck(name: "Xcode Version", status: .ok, message: version, fix: nil)
    }

    func checkBootedSimulator() async -> DoctorCheck {
        do {
            let device = try await SimulatorManager.live.bootedDevice()
            return DoctorCheck(
                name: "Booted Simulator", status: .ok,
                message: "\(device.name) — \(device.runtime)", fix: nil
            )
        } catch {
            return DoctorCheck(
                name: "Booted Simulator", status: .warning,
                message: "No simulator booted",
                fix: "Run: xcrun simctl boot \"iPhone 16\""
            )
        }
    }

    func checkRunner() async -> DoctorCheck {
        let fm = FileManager.default
        let runnerPath = RunnerManager.binaryPath
        if fm.fileExists(atPath: runnerPath) {
            return DoctorCheck(
                name: "Runner", status: .ok,
                message: "grantiva-runner \(RunnerManager.runnerVersion)",
                fix: nil
            )
        }
        return DoctorCheck(
            name: "Runner", status: .warning,
            message: "Not extracted — will be extracted on first use",
            fix: "Run: grantiva runner install"
        )
    }

    func checkGrantivaConfig() -> DoctorCheck {
        if FileManager.default.fileExists(atPath: "grantiva.yml") {
            return DoctorCheck(name: "grantiva.yml", status: .ok, message: "Found", fix: nil, section: .project)
        }
        return DoctorCheck(
            name: "grantiva.yml", status: .warning,
            message: "Not found",
            fix: "Run: grantiva init",
            section: .project
        )
    }

    func checkGitRepository() -> DoctorCheck {
        if FileManager.default.fileExists(atPath: ".git") {
            return DoctorCheck(name: "Git Repository", status: .ok, message: "Detected", fix: nil, section: .project)
        }
        return DoctorCheck(
            name: "Git Repository", status: .warning,
            message: "Not a git repository",
            fix: "Run: git init",
            section: .project
        )
    }

    func checkGrantivaAuth() -> DoctorCheck {
        if ProcessInfo.processInfo.environment["GRANTIVA_API_KEY"] != nil {
            return DoctorCheck(
                name: "Grantiva Auth", status: .ok,
                message: "Authenticated via GRANTIVA_API_KEY", fix: nil, section: .cloud
            )
        }
        if let credentials = AuthStore.live.load() {
            let prefix = String(credentials.apiKey.prefix(8))
            return DoctorCheck(
                name: "Grantiva Auth", status: .ok,
                message: "Authenticated via ~/.grantiva/auth.json (\(prefix)...)", fix: nil, section: .cloud
            )
        }
        return DoctorCheck(
            name: "Grantiva Auth", status: .warning,
            message: "Not authenticated — remote baselines unavailable",
            fix: "Run: grantiva auth login",
            section: .cloud
        )
    }

    func checkGitHubApp() -> DoctorCheck {
        if ProcessInfo.processInfo.environment["GITHUB_APP_ID"] != nil,
           ProcessInfo.processInfo.environment["GITHUB_APP_PRIVATE_KEY"] != nil {
            return DoctorCheck(name: "GitHub App", status: .ok, message: "GITHUB_APP_ID and GITHUB_APP_PRIVATE_KEY set", fix: nil, section: .cloud)
        }
        return DoctorCheck(
            name: "GitHub App", status: .warning,
            message: "GitHub App not configured — Check Runs won't be posted",
            fix: "Install the GitHub App from your Grantiva dashboard settings",
            section: .cloud
        )
    }
}
