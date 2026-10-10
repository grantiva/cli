import Foundation

public struct DoctorRunner: Sendable {
    public init() {}

    public func runAllChecks() async -> [DoctorCheck] {
        await runAllChecks(platforms: [.ios], required: true)
    }

    /// `platforms` are the toolchains to inspect; `required` says whether a
    /// missing toolchain is an error (a detected project) or advice (nothing
    /// detected, so both platforms are reported).
    public func runAllChecks(platforms: [Platform], required: Bool) async -> [DoctorCheck] {
        var checks: [DoctorCheck] = []
        if platforms.contains(.ios) {
            checks.append(await checkXcode(required: required))
            checks.append(await checkXcodeVersion(required: required))
            checks.append(await checkBootedSimulator())
        }
        if platforms.contains(.android) {
            let sdk = AndroidSDK.locate()
            checks.append(checkAndroidSDK(sdk: sdk, required: required))
            if let sdk {
                checks.append(await checkADB(sdk: sdk, required: required))
                checks.append(checkEmulatorBinary(sdk: sdk, required: required))
                checks.append(await checkJDK(required: required))
                let manager = EmulatorManager(sdk: sdk, adb: ADB(path: sdk.adb))
                checks.append(await checkAVDs(list: { (try? await manager.listAVDs()) ?? [] }))
                checks.append(await checkRunningEmulator(adb: ADB(path: sdk.adb)))
            }
        }
        checks.append(await checkRunner())
        for platform in platforms {
            checks.append(checkConfig(for: platform))
        }
        checks.append(checkGitRepository())
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
    func checkXcode(required: Bool = true) async -> DoctorCheck {
        let missing = DoctorCheck(
            name: "Xcode", status: required ? .error : .warning,
            message: "Xcode not found",
            fix: "Install Xcode from the App Store and run: xcode-select --install"
        )
        guard let path = try? await shell("xcode-select -p"), !path.isEmpty else { return missing }
        guard FileManager.default.fileExists(atPath: path) else {
            return DoctorCheck(
                name: "Xcode", status: required ? .error : .warning,
                message: "\(path) does not exist",
                fix: "Point at an installed Xcode: sudo xcode-select -s /Applications/Xcode.app (or unset DEVELOPER_DIR)"
            )
        }
        return DoctorCheck(name: "Xcode", status: .ok, message: path, fix: nil)
    }

    func checkXcodeVersion(required: Bool = true) async -> DoctorCheck {
        let unknown = DoctorCheck(
            name: "Xcode Version", status: required ? .error : .warning,
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
            return Self.noBootedSimulatorCheck(newestIPhone: await SimulatorManager.live.newestIPhone())
        }
    }

    /// Names an iPhone type this host has, not a hardcoded model that newer
    /// Xcodes no longer ship.
    static func noBootedSimulatorCheck(newestIPhone: String?) -> DoctorCheck {
        DoctorCheck(
            name: "Booted Simulator", status: .warning,
            message: "No simulator booted",
            fix: "Run: grantiva simulator ensure --name \"\(newestIPhone ?? "iPhone 17 Pro")\""
        )
    }

    func checkRunner(
        runnerPath: String = RunnerManager.binaryPath,
        versionFilePath: String = RunnerManager.versionFilePath,
        expectedVersion: String = RunnerManager.installStamp
    ) async -> DoctorCheck {
        let fm = FileManager.default
        if fm.fileExists(atPath: runnerPath) {
            let installedVersion = fm.contents(atPath: versionFilePath)
                .flatMap { String(data: $0, encoding: .utf8) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let installedVersion, installedVersion == expectedVersion else {
                let found = installedVersion.flatMap { $0.isEmpty ? nil : $0 } ?? "unknown"
                return DoctorCheck(
                    name: "Runner", status: .warning,
                    message: "Installed grantiva-runner \(found); expected \(expectedVersion)",
                    fix: "Run: grantiva runner install"
                )
            }
            return DoctorCheck(
                name: "Runner", status: .ok,
                message: "grantiva-runner \(installedVersion)",
                fix: nil
            )
        }
        return DoctorCheck(
            name: "Runner", status: .warning,
            message: "Not extracted — will be extracted on first use",
            fix: "Run: grantiva runner install"
        )
    }

    func checkAndroidSDK(
        sdk: AndroidSDK?, required: Bool,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DoctorCheck {
        guard let sdk else {
            return DoctorCheck(
                name: "Android SDK", status: required ? .error : .warning,
                message: "Not found (ANDROID_HOME, ANDROID_SDK_ROOT, ~/Library/Android/sdk)",
                fix: "Run: scripts/android-env.sh, or set ANDROID_HOME"
            )
        }
        let stale = AndroidSDK.staleEnvironmentVariables(environment: environment)
        if !stale.isEmpty {
            let detail = stale.map { "\($0.name)=\($0.value)" }.joined(separator: " and ")
            return DoctorCheck(
                name: "Android SDK", status: .warning,
                message: "\(sdk.root) (\(detail) \(stale.count == 1 ? "has" : "have") no platform-tools/adb; unset or fix \(stale.count == 1 ? "it" : "them"))",
                fix: "Gradle and adb run from this shell still read \(stale.map(\.name).joined(separator: " and ")); export ANDROID_HOME=\(sdk.root)"
            )
        }
        return DoctorCheck(name: "Android SDK", status: .ok, message: sdk.root, fix: nil)
    }

    func checkADB(sdk: AndroidSDK, required: Bool) async -> DoctorCheck {
        guard let version = try? await shell("\(shellQuoted(sdk.adb)) version | head -1"), !version.isEmpty else {
            return DoctorCheck(name: "adb", status: required ? .error : .warning, message: "\(sdk.adb) did not run", fix: "Run: sdkmanager platform-tools")
        }
        return DoctorCheck(name: "adb", status: .ok, message: version, fix: nil)
    }

    func checkEmulatorBinary(sdk: AndroidSDK, required: Bool) -> DoctorCheck {
        guard FileManager.default.fileExists(atPath: sdk.emulator) else {
            return DoctorCheck(name: "Android Emulator", status: required ? .error : .warning, message: "Not installed", fix: "Run: sdkmanager emulator")
        }
        return DoctorCheck(name: "Android Emulator", status: .ok, message: sdk.emulator, fix: nil)
    }

    func checkJDK(required: Bool) async -> DoctorCheck {
        guard let home = await AndroidSDK.javaHome() else {
            return DoctorCheck(name: "JDK", status: required ? .error : .warning, message: "No JDK found (JAVA_HOME or /usr/libexec/java_home)", fix: "Run: brew install openjdk@21 and set JAVA_HOME (see docs/android-environment.md)")
        }
        return DoctorCheck(name: "JDK", status: .ok, message: home, fix: nil)
    }

    func checkAVDs(list: () async -> [String]) async -> DoctorCheck {
        let avds = await list()
        guard !avds.isEmpty else {
            return DoctorCheck(name: "Android AVDs", status: .warning, message: "No AVD exists", fix: "Run: scripts/android-env.sh (creates Pixel_8_API_35)")
        }
        return DoctorCheck(name: "Android AVDs", status: .ok, message: avds.joined(separator: ", "), fix: nil)
    }

    func checkRunningEmulator(adb: ADB) async -> DoctorCheck {
        let running = ((try? await adb.devices()) ?? []).filter { $0.isEmulator && $0.isUsable }
        guard !running.isEmpty else {
            return DoctorCheck(name: "Running Emulator", status: .warning, message: "No emulator running", fix: "Grantiva boots the configured AVD on demand; or run: emulator -avd Pixel_8_API_35")
        }
        return DoctorCheck(name: "Running Emulator", status: .ok, message: running.map(\.serial).joined(separator: ", "), fix: nil)
    }

    func checkConfig(for platform: Platform, directory: String = FileManager.default.currentDirectoryPath) -> DoctorCheck {
        let name = platform.configFileName
        let path = "\(directory)/\(name)"
        if FileManager.default.fileExists(atPath: path) {
            // The same load `run` does, so a file `run` refuses is not "Found".
            do {
                _ = try GrantivaConfig.load(platform: platform, from: URL(fileURLWithPath: directory, isDirectory: true))
            } catch {
                var message = (error as? GrantivaError).flatMap { error -> String? in
                    if case .invalidArgument(let message) = error { return message }
                    return nil
                } ?? error.localizedDescription
                if message.hasPrefix("\(name) ") { message.removeFirst(name.count + 1) }
                let firstLine = message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? message
                return DoctorCheck(
                    name: name, status: .error, message: firstLine,
                    fix: "Fix the YAML in \(path)",
                    section: .project
                )
            }
            return DoctorCheck(name: name, status: .ok, message: "Found", fix: nil, section: .project)
        }
        return DoctorCheck(
            name: name, status: .warning, message: "Not found",
            fix: platform == .ios ? "Run: grantiva init" : "Run: grantiva init --platform android",
            section: .project
        )
    }

    /// Passes anywhere inside a work tree: walks up from `directory` for a
    /// `.git` entry, a directory or (in worktrees and submodules) a file.
    func checkGitRepository(directory: String = FileManager.default.currentDirectoryPath) -> DoctorCheck {
        var url = URL(fileURLWithPath: directory, isDirectory: true).standardizedFileURL
        var insideWorkTree = false
        while true {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path) {
                insideWorkTree = true
                break
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        if insideWorkTree {
            return DoctorCheck(name: "Git Repository", status: .ok, message: "Detected", fix: nil, section: .project)
        }
        return DoctorCheck(
            name: "Git Repository", status: .warning,
            message: "Not a git repository",
            fix: "Run: git init",
            section: .project
        )
    }

    func checkGrantivaAuth(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        storedCredentials: AuthCredentials? = AuthStore.live.load()
    ) -> DoctorCheck {
        if let apiKey = environment["GRANTIVA_API_KEY"],
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return DoctorCheck(
                name: "Grantiva Auth", status: .ok,
                message: "Authenticated via GRANTIVA_API_KEY", fix: nil, section: .cloud
            )
        }
        if let credentials = storedCredentials, !credentials.apiKey.isEmpty {
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
