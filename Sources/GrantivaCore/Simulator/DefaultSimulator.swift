import Foundation

/// The simulator every command uses when neither a flag nor the config file
/// names one: `run`, `diff capture`, `runner start`, the MCP build, test and
/// boot tools, doctor's fix line and the `simulator:` that `init` writes.
///
/// It is the newest iPhone device type an installed iOS runtime can run, so a
/// fresh host gets a name `grantiva simulator ensure --name` can create, never
/// a model that newer Xcodes no longer ship.
public enum DefaultSimulator {
    /// The name used when simctl cannot be asked (no Xcode, a broken
    /// `DEVELOPER_DIR`) or lists no iPhone type an installed runtime runs.
    public static let fallback = "iPhone 17 Pro"

    /// The newest installed iPhone type, read once per process; nil when
    /// simctl is unavailable or no iOS runtime is installed.
    public static let resolved: String? = SimulatorManager.newestIPhone(catalogJSON: catalogJSON() ?? Data())

    /// The default simulator name.
    public static var name: String { resolved ?? fallback }

    /// The default for a given `simctl list devicetypes runtimes --json`.
    static func name(catalogJSON: Data?) -> String {
        catalogJSON.flatMap(SimulatorManager.newestIPhone(catalogJSON:)) ?? fallback
    }

    /// The hint added to "Simulator not found" for the default name, which
    /// the user never typed and so may not know how to create or replace.
    static func notFoundHint(for name: String) -> String? {
        guard name == Self.name else { return nil }
        return " It is Grantiva's default simulator: create it with `grantiva simulator ensure --name \"\(name)\"`, "
            + "or pass --simulator <name|UDID> or set simulator: in grantiva.yml."
    }

    /// The phrase tool schemas use for the default. Static on purpose: a
    /// schema is built at registration, and finding the name runs simctl.
    public static let description = "the newest installed iPhone type"

    /// `simctl list devicetypes runtimes --json`, or nil when it fails or
    /// takes longer than `timeout` (it is then killed): a wedged
    /// CoreSimulatorService must not hang every command that needs a default.
    static func catalogJSON(
        executable: String = "/usr/bin/xcrun",
        arguments: [String] = ["simctl", "list", "devicetypes", "runtimes", "--json"],
        timeout: TimeInterval = 5
    ) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return nil }
        let output = OutputCollector()
        let reader = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            output.set(pipe.fileHandleForReading.readDataToEndOfFile())
            reader.signal()
        }
        guard exited.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            if exited.wait(timeout: .now() + 1) != .success { kill(process.processIdentifier, SIGKILL) }
            return nil
        }
        _ = reader.wait(timeout: .now() + 1)
        return process.terminationStatus == 0 ? output.value : nil
    }
}

private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    var value: Data? { lock.withLock { data } }
    func set(_ data: Data) { lock.withLock { self.data = data } }
}
