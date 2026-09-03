import Foundation

public func shell(_ command: String, environment: [String: String]? = nil) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-c", command]
    if let environment {
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    }
    let pipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = pipe
    process.standardError = errorPipe

    // Every subprocess Grantiva runs, at debug level: this is what `--verbose`
    // is for. When simctl or xcodebuild misbehaves, the exact invocation is the
    // first thing anyone asks for.
    GrantivaLog.logger.debug("$ \(command)")

    try process.run()

    // Drain both pipes concurrently. Reading either stream to EOF first can
    // deadlock when the child fills the other stream's kernel pipe buffer.
    async let data = readToEndOfFile(pipe.fileHandleForReading)
    async let errData = readToEndOfFile(errorPipe.fileHandleForReading)

    process.waitUntilExit()
    let (outputData, errorData) = await (data, errData)
    GrantivaLog.logger.debug("exit \(process.terminationStatus): \(command)")

    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard process.terminationStatus == 0 else {
        let errOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        throw GrantivaError.commandFailed(
            errOutput.isEmpty ? (output.isEmpty ? command : output) : errOutput,
            process.terminationStatus
        )
    }
    return output
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

public func which(_ tool: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = [tool]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return path?.isEmpty == false ? path : nil
}
