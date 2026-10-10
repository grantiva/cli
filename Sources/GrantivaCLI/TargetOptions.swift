import ArgumentParser
import Foundation
import GrantivaCore

/// The flags that name what to build and where to run it, for both
/// platforms. A command declares this once; which half applies is decided by
/// the resolved platform, and a flag from the other half is an error.
struct TargetOptions: ParsableArguments {
    @Option(name: .long, help: "Scheme to build (iOS)")
    var scheme: String?

    @Option(name: .long, help: "Simulator name or UDID (iOS)")
    var simulator: String?

    @Option(name: .long, help: "Bundle identifier (iOS)")
    var bundleId: String?

    @Option(name: .long, help: "Gradle module to assemble (Android; default app)")
    var module: String?

    @Option(name: .long, help: "Gradle build variant, e.g. debug or freeDebug (Android; default debug)")
    var variant: String?

    @Option(name: .long, help: "Application ID (Android; read from the build or the APK when omitted)")
    var applicationId: String?

    @Option(name: .long, help: "AVD name to use, booting it if needed (Android)")
    var emulator: String?

    @Option(name: .long, help: "adb serial of an attached emulator or physical device (Android)")
    var device: String?

    @Flag(name: .long, help: "Apply demo mode and animation settings on a physical device too (Android)")
    var allowDeviceSettings = false

    @Flag(name: .long, help: "Boot an emulator without a window (Android)")
    var headless = false

    var androidOptions: AndroidPlatform.Options {
        AndroidPlatform.Options(allowDeviceSettings: allowDeviceSettings, headless: headless)
    }

    /// Rejects flags that belong to the other platform, naming the flag.
    func checkFlags(for platform: Platform, derivedDataPath: String?, logsPredicate: String? = nil, logsTag: String? = nil) throws {
        let iosFlags: [(String, Bool)] = [
            ("--scheme", scheme != nil), ("--simulator", simulator != nil), ("--bundle-id", bundleId != nil),
            ("--derived-data-path", derivedDataPath != nil), ("--logs-predicate", logsPredicate != nil),
        ]
        let androidFlags: [(String, Bool)] = [
            ("--module", module != nil), ("--variant", variant != nil), ("--application-id", applicationId != nil),
            ("--emulator", emulator != nil), ("--device", device != nil), ("--allow-device-settings", allowDeviceSettings),
            ("--headless", headless), ("--logs-tag", logsTag != nil),
        ]
        let wrong = platform == .ios ? androidFlags : iosFlags
        if let offending = wrong.first(where: { $0.1 })?.0 {
            throw Self.otherPlatformFlagError(offending, platform: platform)
        }
        if device != nil, emulator != nil {
            throw GrantivaError.invalidArgument("--device and --emulator are mutually exclusive; pass one.")
        }
        if let device {
            _ = try DeviceID.validate(device, flag: "--device")
        }
    }

    static func otherPlatformFlagError(_ flag: String, platform: Platform) -> GrantivaError {
        let owner = platform == .ios ? "an Android" : "an iOS"
        return GrantivaError.invalidArgument(
            "\(flag) is \(owner) option, but this is \(platform == .ios ? "an iOS" : "an Android") project "
                + "(resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory)."
        )
    }

    func resolve(platform: Platform, config: GrantivaConfig?, skipBuild: Bool, appID: String?) async throws -> ResolvedProject {
        switch platform {
        case .ios:
            return try await ResolvedProject.resolve(
                schemeFlag: scheme, simulatorFlag: simulator, bundleIdFlag: bundleId, config: config,
                skipBuild: skipBuild, appBundleId: appID
            )
        case .android:
            return try Self.resolveAndroid(
                moduleFlag: module, variantFlag: variant, applicationIdFlag: applicationId,
                emulatorFlag: emulator, deviceFlag: device, config: config, appID: appID
            )
        }
    }

    /// Flags over config over the binary's manifest. No Gradle parsing and no
    /// detection cache: a missing module or variant is the default.
    static func resolveAndroid(
        moduleFlag: String?, variantFlag: String?, applicationIdFlag: String?,
        emulatorFlag: String?, deviceFlag: String?, config: GrantivaConfig?, appID: String?
    ) throws -> ResolvedProject {
        let configured = config?.android ?? AndroidProject()
        let applicationId = applicationIdFlag ?? configured.applicationId ?? appID
        if let applicationId, applicationId.wholeMatch(of: /[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+/) == nil {
            throw GrantivaError.invalidArgument(
                "Application ID \"\(applicationId)\" is not a valid Android application ID (letters, digits, underscores, at least one dot)."
            )
        }
        let android = AndroidProject(
            module: moduleFlag ?? configured.module,
            variant: variantFlag ?? configured.variant,
            applicationId: applicationId,
            emulator: emulatorFlag ?? configured.emulator,
            systemImage: configured.systemImage,
            buildArgs: configured.buildArgs
        )
        return ResolvedProject(
            bundleId: applicationId,
            buildSettings: configured.buildArgs,
            simulator: deviceFlag ?? android.emulator ?? "",
            screens: config?.screens ?? [],
            flows: config?.flows ?? [],
            diff: config?.diff ?? .init(),
            a11y: config?.a11y ?? .init(),
            android: android
        )
    }

    func extraBuildSettings(platform: Platform, derivedDataPath: String?, resolved: ResolvedProject) -> [String] {
        switch platform {
        case .ios:
            return BuildOptions.xcodeBuildSettings(derivedDataPath: derivedDataPath, merging: resolved.buildSettings)
        case .android:
            return resolved.buildSettings
        }
    }

    static func appIDMessage(for platform: Platform) -> String {
        switch platform {
        case .ios:
            return "Bundle ID is required to run flows. Pass --bundle-id or set bundle_id in grantiva.yml."
        case .android:
            return "Application ID is required. Pass --application-id, set application_id in grantiva-android.yml, build from source, or pass --app-file <apk>."
        }
    }
}
