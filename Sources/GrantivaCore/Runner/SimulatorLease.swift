import Darwin
import Foundation

/// A cross-process lease that prevents two Grantiva runner invocations from
/// managing WebDriverAgent on the same simulator at the same time.
///
/// The embedded runner owns WDA for the lifetime of a test process. Starting a
/// second runner against the same UDID can replace the first runner's WDA
/// session and then tear it down. An advisory file lock makes that ownership
/// explicit while still allowing full concurrency across distinct simulators.
public final class SimulatorLease: @unchecked Sendable {
    private let descriptor: Int32
    public let udid: String
    public let path: String
    private var released = false
    private let stateLock = NSLock()

    public static func acquire(
        udid: String,
        directory: String? = nil
    ) throws -> SimulatorLease {
        let directory = directory ?? RunnerManager.baseDir + "/locks"
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        let safeUDID = udid.replacingOccurrences(
            of: "[^A-Za-z0-9._-]",
            with: "_",
            options: .regularExpression
        )
        let path = "\(directory)/\(safeUDID).lock"
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw GrantivaError.commandFailed(
                "Could not create simulator lease at \(path): \(String(cString: strerror(errno)))",
                1
            )
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let lockError = errno
            Darwin.close(descriptor)
            if lockError == EWOULDBLOCK {
                throw GrantivaError.commandFailed(
                    "Simulator \(udid) is already owned by another Grantiva run. "
                        + "Use `grantiva simulator ensure --name <unique-name>` and pass that simulator, "
                        + "or wait for the active run to finish.",
                    1
                )
            }
            throw GrantivaError.commandFailed(
                "Could not lock simulator \(udid): \(String(cString: strerror(lockError)))",
                1
            )
        }

        // Keep lightweight diagnostics in the lock file. The lock itself, not
        // this content, is the source of truth and is released by the kernel if
        // the process exits or crashes.
        let owner = "pid=\(getpid()) started_at=\(ISO8601DateFormatter().string(from: Date()))\n"
        _ = ftruncate(descriptor, 0)
        _ = owner.withCString { pointer in
            Darwin.write(descriptor, pointer, strlen(pointer))
        }

        return SimulatorLease(descriptor: descriptor, udid: udid, path: path)
    }

    private init(descriptor: Int32, udid: String, path: String) {
        self.descriptor = descriptor
        self.udid = udid
        self.path = path
    }

    public func release() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !released else { return }
        released = true
        _ = flock(descriptor, LOCK_UN)
        Darwin.close(descriptor)
    }

    deinit {
        release()
    }
}
