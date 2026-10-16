import Foundation

/// Runs `command` under `/bin/zsh -c` and returns its trimmed stdout.
///
/// The child's stdin is the null device, never Grantiva's own: `grantiva mcp`
/// speaks JSON-RPC on stdin, and a child such as `adb shell` forwards whatever
/// it inherits to the device, swallowing the client's queued requests.
///
/// `terminateOnCancel` stops the child (SIGTERM) when the calling task is
/// cancelled while it runs, as a cancelled MCP `grantiva_build` must stop its
/// xcodebuild or Gradle (L14). A task already cancelled when the command
/// starts (cleanup after a cancellation) still runs it to the end.
public func shell(_ command: String, environment: [String: String]? = nil, terminateOnCancel: Bool = false) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]
    if let environment {
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    }
    let pipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = pipe
    process.standardError = errorPipe

    // Every subprocess Grantiva runs, at debug level: this is what `--verbose`
    // is for. When simctl or xcodebuild misbehaves, the exact invocation is the
    // first thing anyone asks for.
    GrantivaLog.logger.debug("$ \(command)")

    let stopOnCancel = terminateOnCancel && !Task.isCancelled
    try process.run()
    let tracked = ShellChildren.shared.register(process.processIdentifier)
    defer { ShellChildren.shared.unregister(tracked) }

    // Drain both pipes concurrently. Reading either stream to EOF first can
    // deadlock when the child fills the other stream's kernel pipe buffer.
    async let data = readToEndOfFile(pipe.fileHandleForReading)
    async let errData = readToEndOfFile(errorPipe.fileHandleForReading)

    await withTaskCancellationHandler {
        process.waitUntilExit()
    } onCancel: {
        if stopOnCancel, process.isRunning { process.terminate() }
    }
    let (outputData, errorData) = await (data, errData)
    GrantivaLog.logger.debug("exit \(process.terminationStatus): \(command)")

    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard process.terminationStatus == 0 else {
        let errOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        throw GrantivaError.commandFailed(
            errOutput.isEmpty ? (output.isEmpty ? "\(command) exited with code \(process.terminationStatus)" : output) : errOutput,
            process.terminationStatus
        )
    }
    return output
}

/// The `shell`/`runProcess` children running now, so an interrupt can end
/// them (C13-3). Foundation starts each in a process group of its own, so a
/// terminal's Ctrl-C does not reach one and nothing else would: a
/// `simctl status_bar ... override` that was running when grantiva exited
/// was left to launchd.
public final class ShellChildren: @unchecked Sendable {
    public static let shared = ShellChildren()

    private let lock = NSLock()
    private var children: [UInt64: pid_t] = [:]
    private var nextID: UInt64 = 1

    func register(_ pid: pid_t) -> UInt64 {
        lock.withLock {
            let id = nextID
            nextID += 1
            if pid > 1 { children[id] = pid }
            return id
        }
    }

    func unregister(_ id: UInt64) {
        lock.withLock { _ = children.removeValue(forKey: id) }
    }

    /// The pids of the children running now.
    public var running: [pid_t] {
        lock.withLock { Array(children.values).sorted() }
    }

    /// SIGTERM each running child (and the group it leads), then SIGKILL
    /// whatever is still alive after `gracePeriod`. Blocks at most about
    /// `gracePeriod` plus a moment.
    public func terminateAll(gracePeriod: TimeInterval = 2) {
        let pids = running
        guard !pids.isEmpty else { return }
        let ownGroup = getpgrp()
        func send(_ sig: Int32, _ pid: pid_t) {
            if getpgid(pid) == pid, pid != ownGroup { kill(-pid, sig) }
            kill(pid, sig)
        }
        pids.forEach { send(SIGTERM, $0) }
        let deadline = Date().addingTimeInterval(gracePeriod)
        // A child is reaped by its waiter, which unregisters it.
        func alive() -> [pid_t] { Set(running).intersection(pids).filter { kill($0, 0) == 0 } }
        while Date() < deadline, !alive().isEmpty { usleep(50_000) }
        alive().forEach { send(SIGKILL, $0) }
    }
}

private func readToEndOfFile(_ handle: FileHandle) async -> Data {
    await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(returning: handle.readDataToEndOfFile())
        }
    }
}

/// Quotes one argument for `/bin/zsh -c`: single quotes, with embedded single
/// quotes closed, escaped, and reopened. Every value that reaches `shell` from
/// user or model input (schemes, paths, screen names) must go through here.
public func shellQuoted(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

/// Resolves `tool` on PATH. Like `shell`, the child gets a null stdin so it
/// can never consume the MCP server's input.
public func which(_ tool: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [tool]
    process.standardInput = FileHandle.nullDevice
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return path?.isEmpty == false ? path : nil
}

/// `shell` for an argument vector: runs `argv[0]` with `argv[1...]` directly,
/// so nothing in an argument is interpreted by a shell. Same contract: null
/// stdin, trimmed stdout, a non-zero exit throws `commandFailed` with stderr
/// (or stdout).
///
/// The exit is observed through the termination handler rather than
/// `waitUntilExit()`: called after an `await`, on a cooperative thread,
/// `waitUntilExit()` was seen to block forever after the child had exited.
public func runProcess(_ argv: [String], environment: [String: String]? = nil) async throws -> String {
    precondition(!argv.isEmpty, "runProcess needs an executable")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: argv[0])
    process.arguments = Array(argv.dropFirst())
    if let environment {
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    }
    let stdout = Pipe()
    let stderr = Pipe()
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = stdout
    process.standardError = stderr
    let command = argv.map(shellQuoted).joined(separator: " ")
    GrantivaLog.logger.debug("$ \(command)")
    let exited = AsyncStream<Void> { continuation in
        process.terminationHandler = { _ in
            continuation.yield()
            continuation.finish()
        }
    }
    try process.run()
    let tracked = ShellChildren.shared.register(process.processIdentifier)
    defer { ShellChildren.shared.unregister(tracked) }
    // Drain both pipes concurrently so neither fills and blocks the child.
    async let out = readToEndOfFile(stdout.fileHandleForReading)
    async let err = readToEndOfFile(stderr.fileHandleForReading)
    let (outData, errData) = await (out, err)
    for await _ in exited {}
    GrantivaLog.logger.debug("exit \(process.terminationStatus): \(command)")
    let output = String(decoding: outData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0 else {
        let errors = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        throw GrantivaError.commandFailed(
            errors.isEmpty ? (output.isEmpty ? "\(command) exited with code \(process.terminationStatus)" : output) : errors,
            process.terminationStatus
        )
    }
    return output
}
