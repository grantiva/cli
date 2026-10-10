import Foundation
import Yams

public struct GrantivaConfig: Sendable, Codable {
    public var scheme: String?
    public var workspace: String?
    public var project: String?
    public var simulator: String?
    public var bundleId: String?
    public var buildSettings: [String]?
    public var screens: [Screen]
    /// Paths to external Maestro YAML flow files to run in addition to `screens`.
    public var flows: [String]
    public var diff: DiffConfig
    public var a11y: A11yConfig
    /// Which platform this file describes. `.ios` for grantiva.yml and
    /// Maestro-format input; `.android` for grantiva-android.yml.
    public var platform: Platform = .ios
    /// Gradle-side settings. Present only when `platform == .android`.
    public var android: AndroidProject?

    public struct Screen: Sendable, Codable {
        public var name: String
        public var path: ScreenPath

        public struct Step: Sendable, Codable {
            public var tap: String?
            public var swipe: String?
            public var type: String?
            public var wait: Double?
            public var assertVisible: String?
            public var assertNotVisible: String?
            public var runFlow: String?
            /// Set when the Maestro source selected by `id:`: the label is an
            /// accessibility identifier, not text. Only the Maestro parser
            /// sets these; they are not grantiva.yml keys.
            public var tapById: Bool = false
            public var assertVisibleById: Bool = false
            public var assertNotVisibleById: Bool = false
            /// Maestro `swipe: {from: ...}`: the element the swipe starts on.
            public var swipeFrom: String? = nil
            public var swipeFromById: Bool = false
            /// Maestro `waitForAnimationToEnd`: wait until the screen is still,
            /// for at most this many seconds. Unlike `wait`, it returns early.
            public var settle: Double? = nil

            /// The directions a swipe step takes, lowercased.
            static let swipeDirectionNames = ["up", "down", "left", "right"]

            public init(
                tap: String? = nil, swipe: String? = nil, type: String? = nil,
                wait: Double? = nil, assertVisible: String? = nil,
                assertNotVisible: String? = nil, runFlow: String? = nil,
                tapById: Bool = false, assertVisibleById: Bool = false,
                assertNotVisibleById: Bool = false,
                swipeFrom: String? = nil, swipeFromById: Bool = false,
                settle: Double? = nil
            ) {
                self.tap = tap
                self.swipe = swipe
                self.type = type
                self.wait = wait
                self.assertVisible = assertVisible
                self.assertNotVisible = assertNotVisible
                self.runFlow = runFlow
                self.tapById = tapById
                self.assertVisibleById = assertVisibleById
                self.assertNotVisibleById = assertNotVisibleById
                self.swipeFrom = swipeFrom
                self.swipeFromById = swipeFromById
                self.settle = settle
            }

            enum CodingKeys: String, CodingKey {
                case tap, swipe, type, wait
                case assertVisible = "assert_visible"
                case assertNotVisible = "assert_not_visible"
                case runFlow = "run_flow"
            }
        }

        public init(name: String, path: ScreenPath) {
            self.name = name
            self.path = path
        }
    }

    public enum ScreenPath: Sendable {
        case launch
        case steps([Screen.Step])
    }

    public struct DiffConfig: Sendable, Codable {
        public var threshold: Double
        public var perceptualThreshold: Double

        public init(threshold: Double = 0.02, perceptualThreshold: Double = 5.0) {
            self.threshold = threshold
            self.perceptualThreshold = perceptualThreshold
        }

        enum CodingKeys: String, CodingKey {
            case threshold
            case perceptualThreshold = "perceptual_threshold"
        }
    }

    public struct A11yConfig: Sendable, Codable {
        public var rules: [String]

        public init(rules: [String] = ["missing_label", "small_tap_target"]) {
            self.rules = rules
        }
    }

    enum CodingKeys: String, CodingKey {
        case scheme, workspace, project, simulator
        case bundleId = "bundle_id"
        case buildSettings = "build_settings"
        case screens, flows, diff, a11y
        case platform
    }

    public init(
        scheme: String? = nil,
        workspace: String? = nil,
        project: String? = nil,
        simulator: String? = nil,
        bundleId: String? = nil,
        buildSettings: [String]? = nil,
        screens: [Screen] = [],
        flows: [String] = [],
        diff: DiffConfig = .init(),
        a11y: A11yConfig = .init(),
        platform: Platform = .ios,
        android: AndroidProject? = nil
    ) {
        self.scheme = scheme
        self.workspace = workspace
        self.project = project
        self.simulator = simulator
        self.bundleId = bundleId
        self.buildSettings = buildSettings
        self.screens = screens
        self.flows = flows
        self.diff = diff
        self.a11y = a11y
        self.platform = platform
        self.android = android
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scheme = try container.decodeIfPresent(String.self, forKey: .scheme)
        workspace = try container.decodeIfPresent(String.self, forKey: .workspace)
        project = try container.decodeIfPresent(String.self, forKey: .project)
        simulator = try container.decodeIfPresent(String.self, forKey: .simulator)
        bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
        buildSettings = try container.decodeIfPresent([String].self, forKey: .buildSettings)
        screens = try container.decodeIfPresent([Screen].self, forKey: .screens) ?? []
        flows = try container.decodeIfPresent([String].self, forKey: .flows) ?? []
        diff = try container.decodeIfPresent(DiffConfig.self, forKey: .diff) ?? .init()
        a11y = try container.decodeIfPresent(A11yConfig.self, forKey: .a11y) ?? .init()
        platform = try container.decodeIfPresent(Platform.self, forKey: .platform) ?? .ios
        android = nil
    }

    public static func load(
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig {
        try load(platform: .ios, from: directory)
    }

    /// Loads the config file for `platform`, or throws `configNotFound`.
    /// A file that exists but does not parse is an error carrying the file
    /// name and the YAML diagnostic; it never falls through.
    public static func load(
        platform: Platform,
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) throws -> GrantivaConfig {
        guard let config = try loadIfPresent(platform: platform, from: directory) else {
            throw GrantivaError.configNotFound
        }
        return config
    }

    /// Like `load(platform:from:)` but returns nil when no file exists.
    /// `includeMaestroDirectory: false` skips the `.maestro/` fallback, for a
    /// run that names its own flow and must not parse unrelated files.
    public static func loadIfPresent(
        platform: Platform,
        from directory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        includeMaestroDirectory: Bool = true
    ) throws -> GrantivaConfig? {
        let fm = FileManager.default
        let configURL = directory.appendingPathComponent(platform.configFileName)

        if fm.fileExists(atPath: configURL.path) {
            let contents = try String(contentsOf: configURL, encoding: .utf8)
            return try parse(contents, platform: platform, fileName: platform.configFileName)
        }

        // The .maestro/ fallback is an iOS-era convention; Android has none.
        guard platform == .ios, includeMaestroDirectory else { return nil }
        let maestroDir = directory.appendingPathComponent(".maestro")
        if fm.fileExists(atPath: maestroDir.path) {
            return try MaestroFlowParser.loadDirectory(maestroDir)
        }
        return nil
    }

    static func parse(_ contents: String, platform: Platform, fileName: String) throws -> GrantivaConfig {
        // An empty, whitespace-only, or comments-only file has no YAML
        // document; treat it as "all defaults". Only the first document is
        // read, since Maestro-format files carry several (`Yams.load` throws
        // on a multi-document stream).
        let firstDocument: Node?
        do {
            firstDocument = try Parser(yaml: contents).nextRoot()
        } catch {
            throw GrantivaError.invalidArgument("\(fileName) could not be parsed: \(error)")
        }
        if firstDocument == nil {
            return GrantivaConfig(platform: platform, android: platform == .android ? AndroidProject() : nil)
        }
        if platform == .ios, MaestroFlowParser.isMaestroFormat(contents) {
            do {
                return try MaestroFlowParser.parse(contents, sourceName: fileName)
            } catch let error as GrantivaError {
                // Already names the file and line.
                throw error
            } catch {
                throw GrantivaError.invalidArgument("\(fileName) could not be parsed: \(error)")
            }
        }
        var config: GrantivaConfig
        do {
            config = try YAMLDecoder().decode(GrantivaConfig.self, from: contents)
        } catch {
            throw GrantivaError.invalidArgument("\(fileName) could not be parsed: \(error)")
        }
        if let declared = (try? YAMLDecoder().decode(DeclaredPlatform.self, from: contents))?.platform,
           declared != platform {
            throw GrantivaError.invalidArgument(
                "\(fileName) declares `platform: \(declared.rawValue)` but it is the \(platform.displayName) config file."
            )
        }
        config.platform = platform
        if platform == .android {
            do {
                config.android = try YAMLDecoder().decode(AndroidProject.self, from: contents)
            } catch {
                throw GrantivaError.invalidArgument("\(fileName) could not be parsed: \(error)")
            }
        }
        return config
    }

    private struct DeclaredPlatform: Decodable {
        var platform: Platform?
    }
}

// MARK: - Screen Helpers

extension Array where Element == GrantivaConfig.Screen {
    /// True if any screen requires navigation steps (taps/swipes) to reach.
    public var hasNavigationSteps: Bool {
        contains { screen in
            if case .steps(let steps) = screen.path, !steps.isEmpty {
                return true
            }
            return false
        }
    }
}

// MARK: - ScreenPath Codable

extension GrantivaConfig.ScreenPath: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str == "launch" {
            self = .launch
        } else {
            let steps = try container.decode([GrantivaConfig.Screen.Step].self)
            self = .steps(steps)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .launch:
            try container.encode("launch")
        case .steps(let steps):
            try container.encode(steps)
        }
    }
}
