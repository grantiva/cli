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
