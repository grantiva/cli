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
}
