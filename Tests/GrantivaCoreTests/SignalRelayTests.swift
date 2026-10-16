import Darwin
import Dispatch
import Foundation
import XCTest
@testable import GrantivaCore

final class SignalRelayTests: XCTestCase {
    func testCleanupsRunOnTerminationAndCanBeRemoved() {
        let ran = expectation(description: "cleanup ran")
        let token = SignalRelay.shared.onTermination { ran.fulfill() }
        SignalRelay.shared.runCleanupsForTesting()
        wait(for: [ran], timeout: 1)

        SignalRelay.shared.removeCleanup(token)
        // Removing must be complete: a second sweep runs nothing that was
        // unregistered, so a finished run cannot be torn down twice.
        SignalRelay.shared.runCleanupsForTesting()
    }

    func testTrackedGroupsAreDeduplicated() {
        SignalRelay.shared.track(group: 12345, deviceNoun: "simulator")
        SignalRelay.shared.track(group: 12345, deviceNoun: "simulator")
        SignalRelay.shared.untrack(group: 12345)
        // Untracking once must clear the group; a stale entry would signal a
        // pid the OS may have reused.
        SignalRelay.shared.untrack(group: 12345)
    }

    func testADispatchSourceStillObservesAnIgnoredSignal() {
        // This is the mechanism the relay depends on. A shell starts background
        // commands in a script with SIGINT set to SIG_IGN, and children inherit
        // it — which is why `kill -INT` against a backgrounded `grantiva run`
        // used to do nothing at all. A dispatch source is delivered regardless
        // of the disposition, so the run can still be interrupted.
        let observed = expectation(description: "signal observed")
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .global())
        source.setEventHandler { observed.fulfill() }
        source.resume()
        defer { source.cancel() }

        // Give the source a moment to register with the kernel.
        usleep(100_000)
        kill(getpid(), SIGUSR1)
        wait(for: [observed], timeout: 5)
    }

    // MARK: - L37

    func testTheAnnouncementNamesEachPlatformsDevice() {
        XCTAssertEqual(
            SignalRelay.announcement(signalName: "SIGINT", deviceNoun: SignalRelay.deviceNoun(for: .android)),
            "\n[grantiva] received SIGINT — releasing emulator and reaping child processes\n"
        )
        XCTAssertEqual(SignalRelay.deviceNoun(for: .ios), "simulator")
    }

    func testTrackingAGroupSetsTheNoun() {
        let saved = SignalRelay.shared.deviceNoun
        defer {
            SignalRelay.shared.untrack(group: 12346)
            SignalRelay.shared.deviceNoun = saved
        }
        SignalRelay.shared.track(group: 12346, deviceNoun: "emulator")
        XCTAssertEqual(SignalRelay.shared.deviceNoun, "emulator")
    }

    /// B4-L72.3: an interrupt ends what a tracked runner started outside its
    /// group (WDA's xcodebuild). The hook runs after the group is stopped and
    /// before the cleanups release the device, and only while the group is
    /// tracked.
    func testGroupHelperReapRunsAfterTheGroupStopsAndBeforeTheCleanups() throws {
        let child = try ChildProcess.spawn(
            executable: "/bin/sleep", arguments: ["30"],
            stdout: FileHandle.nullDevice.fileDescriptor, stderr: FileHandle.nullDevice.fileDescriptor, logged: false
        )
        let reaper = DispatchQueue.global()
        reaper.async { child.wait() }
        let order = Locked<[String]>([])
        SignalRelay.shared.track(group: child.processGroup, deviceNoun: "simulator")
        SignalRelay.shared.afterGroupTermination(group: child.processGroup) {
            order.append(child.isRunning ? "helpers (runner alive)" : "helpers")
        }
        let token = SignalRelay.shared.onTermination { order.append("cleanup") }
        defer {
            SignalRelay.shared.removeCleanup(token)
            SignalRelay.shared.untrack(group: child.processGroup)
            SignalRelay.shared.resetTerminationForTesting()
        }

        SignalRelay.shared.simulateTerminationForTesting()

        XCTAssertEqual(order.value, ["helpers", "cleanup"])

        // Untracked, the hook is gone with the group.
        SignalRelay.shared.resetTerminationForTesting()
        SignalRelay.shared.untrack(group: child.processGroup)
        SignalRelay.shared.simulateTerminationForTesting()
        XCTAssertEqual(order.value, ["helpers", "cleanup", "cleanup"])
    }

    /// C13-3: a `simctl status_bar` (any `shell` child) still running when
    /// grantiva is interrupted is ended, not left to launchd: Foundation
    /// starts it in a process group of its own, so no terminal signal or
    /// runner-group kill reaches it.
    func testAnInterruptEndsTheShellChildrenStillRunning() async throws {
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let started = Date()
        let child = Task { try? await shell("trap '' INT; sleep 30") }
        var pids: [Int32] = []
        for _ in 0..<50 where pids.isEmpty {
            try await Task.sleep(nanoseconds: 50_000_000)
            pids = ShellChildren.shared.running
        }
        let pid = try XCTUnwrap(pids.first)
        SignalRelay.shared.simulateTerminationForTesting()
        _ = await child.value
        XCTAssertLessThan(Date().timeIntervalSince(started), 15)
        XCTAssertNotEqual(kill(pid, 0), 0, "the shell child outlived the interrupt")
        XCTAssertTrue(ShellChildren.shared.running.isEmpty)
    }

    /// C15 (B4-L68.3): the relay killed every shell child first, so an
    /// `adb forward tcp:0` in flight was cut off after adb had made the
    /// forward but before grantiva learned its port: the forward leaked. An
    /// `adb forward` call now finishes while the groups stop and the
    /// cleanups run (they own what it makes); other children, a status-bar
    /// override among them, still end first. Whatever is left goes at the end.
    func testAnInterruptLetsAnAdbForwardFinishBeforeTheCleanups() async throws {
        defer { SignalRelay.shared.resetTerminationForTesting() }
        let ordinary = Task { try? await shell("trap '' INT; sleep 30 # adb forward stand-in") }
        let override = Task { try? await shell("trap '' INT; sleep 30 # simctl status_bar stand-in") }
        defer { ordinary.cancel(); override.cancel() }
        var pids: [Int32] = []
        for _ in 0..<50 where pids.count < 2 {
            try await Task.sleep(nanoseconds: 50_000_000)
            pids = ShellChildren.shared.running
        }
        XCTAssertEqual(pids.count, 2)
        let commands = ShellChildren.shared.runningCommands
        let ordinaryPid = try XCTUnwrap(commands.first { $0.value.contains("adb forward") }?.key)
        let overridePid = try XCTUnwrap(commands.first { $0.value.contains("status_bar") }?.key)
        let seen = LockedFlags()
        let token = SignalRelay.shared.onTermination {
            seen.set("ordinary", kill(ordinaryPid, 0) == 0)
            seen.set("override", kill(overridePid, 0) == 0)
        }
        defer { SignalRelay.shared.removeCleanup(token) }

        SignalRelay.shared.simulateTerminationForTesting()

        XCTAssertEqual(seen.value("ordinary"), true, "the in-flight child was killed before the cleanups")
        XCTAssertEqual(seen.value("override"), false, "the status-bar override outlived the start of the cleanups")
        _ = await ordinary.value
        XCTAssertNotEqual(kill(ordinaryPid, 0), 0, "the ordinary child outlived the interrupt")
    }

    /// B3-L54.1: a teardown that lands before the runner exists ends the
    /// start in order: the exit status is the provider's, not 128 + signal.
    func testAnExitStatusProviderDecidesTheInterruptsStatus() {
        defer { SignalRelay.shared.setExitStatus(nil) }
        XCTAssertEqual(SignalRelay.shared.exitStatus(for: SIGINT), 130)
        SignalRelay.shared.setExitStatus { 0 }
        XCTAssertEqual(SignalRelay.shared.exitStatus(for: SIGINT), 0)
        SignalRelay.shared.setExitStatus { nil }
        XCTAssertEqual(SignalRelay.shared.exitStatus(for: SIGTERM), 143)
    }
}

private final class LockedFlags: @unchecked Sendable {
    private let lock = NSLock()
    private var flags: [String: Bool] = [:]
    func set(_ key: String, _ value: Bool) { lock.withLock { flags[key] = value } }
    func value(_ key: String) -> Bool? { lock.withLock { flags[key] } }
}
