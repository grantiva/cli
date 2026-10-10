import Foundation

/// Where the Android command-line tools live. Nothing is installed here;
/// `scripts/android-env.sh` does that.
public struct AndroidSDK: Sendable, Equatable {
    public let root: String

    public init(root: String) {
        self.root = root
    }

    public var adb: String { "\(root)/platform-tools/adb" }
    public var emulator: String { "\(root)/emulator/emulator" }
    public var avdmanager: String { "\(root)/cmdline-tools/latest/bin/avdmanager" }
    public var sdkmanager: String { "\(root)/cmdline-tools/latest/bin/sdkmanager" }
    public var apkanalyzer: String { "\(root)/cmdline-tools/latest/bin/apkanalyzer" }

    public static let missingMessage =
        "Android SDK not found. Set ANDROID_HOME (or ANDROID_SDK_ROOT) to an SDK with platform-tools/adb, "
        + "or run scripts/android-env.sh to install one at ~/Library/Android/sdk."

    /// `ANDROID_HOME`, then `ANDROID_SDK_ROOT`, then `~/Library/Android/sdk`.
    /// A candidate counts only when it holds `platform-tools/adb`.
    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) -> AndroidSDK? {
        let candidates = [
            environment["ANDROID_HOME"],
            environment["ANDROID_SDK_ROOT"],
            "\(home)/Library/Android/sdk",
        ].compactMap { $0 }.filter { !$0.isEmpty }
        for candidate in candidates {
            let sdk = AndroidSDK(root: candidate)
            if fileManager.fileExists(atPath: sdk.adb) {
                return sdk
            }
        }
        return nil
    }

    /// `ANDROID_HOME` / `ANDROID_SDK_ROOT` values that are set but hold no
    /// `platform-tools/adb`, so `locate` skipped them.
    public static func staleEnvironmentVariables(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [(name: String, value: String)] {
        ["ANDROID_HOME", "ANDROID_SDK_ROOT"].compactMap { name in
            guard let value = environment[name], !value.isEmpty,
                  !fileManager.fileExists(atPath: AndroidSDK(root: value).adb) else { return nil }
            return (name, value)
        }
    }

    public static func require(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: String = NSHomeDirectory(),
        fileManager: FileManager = .default
    ) throws -> AndroidSDK {
        guard let sdk = locate(environment: environment, home: home, fileManager: fileManager) else {
            throw GrantivaError.invalidArgument(missingMessage)
        }
        return sdk
    }

    /// `JAVA_HOME` when it names an existing directory, else the output of
    /// `/usr/libexec/java_home`, else nil.
    public static func javaHome(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        execute: @Sendable (String) async throws -> String = { try await shell($0) }
    ) async -> String? {
        if let configured = environment["JAVA_HOME"], !configured.isEmpty, fileManager.fileExists(atPath: configured) {
            return configured
        }
        guard let output = try? await execute("/usr/libexec/java_home") else { return nil }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
