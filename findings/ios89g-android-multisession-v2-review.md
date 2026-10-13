# iOS attempt 89g and Android two-device multisession v2 review

## iOS attempt 89g

Attempt 89g is a valid current lifecycle control. The normal keep-alive leg records distinct parent/runner PIDs, a terminal ready file, a shaped stop document with the exact runner PID and `killed: false`, and clean parent exit. The killed-runner leg sends SIGKILL to the row-owned runner; its Grantiva parent notices and exits nonzero in 0.576 seconds, and `killed-sidecars-after.json` is empty. This supports B3-L11's dead-runner detection/cleanup clause and corroborates normal keep-alive stop behavior.

It does not run the row's SIGHUP-survival sequence, and it kills the runner rather than the owning Grantiva parent. It therefore does not complete B3-L11's HUP clause and does not satisfy B2-K79/D2-30's kill-9-owner input. No broader verdict should be inferred.

Attempt 89h separately completes N2-18's deferred parent-HUP clause. It sends SIGHUP to the nohup-launched Grantiva parent; two seconds later both parent and runner are alive, hierarchy exits 0 with the Landmarks tree, and ordinary runner stop returns the exact runner PID with `killed: false`. Joined with attempt 89e's valid blocked-SIGINT/SIGTERM detached start and first-signal stop, N2-18 `[ios]` is fully supported. Attempt 89h still does not complete B3-L11's distinct instruction to send SIGHUP directly to the runner PID.

## Android `N2-05-B3L13-two-device-multisession-rerun2`

The two-device stop leg is valid despite wrapper exit 10. `active-observations.json` proves two simultaneous keep-alive owners in one project, with different Grantiva/runner PIDs and serials `emulator-5554` and `emulator-5556`. One `runner stop --json` exits 0 and returns exactly two shaped `sessions[]` entries. Each entry carries status stopped, platform, application ID plus deprecated alias, serial plus deprecated UDID, parent `pid`, exact `runnerPid`, nullable port, boolean `killed: false`, and `reaped`.

The secondary run exiting 130 is the expected consequence of stopping it while its flow is active; neither N2-05(b) nor B3-L13 requires both keep-alive parent processes to exit 0. The wrapper's `bothRunsExit0` assertion is therefore an invalid extra condition. The primary had already reached its terminal hold and exits 0. Cleanup removes the row-owned secondary device, while the campaign primary remains.

This completes the two-session clause of N2-05 and B3-L13 `[android]`. Full-row grades still join the separately retained normal detached stop and killed-runner/alreadyExited documents; v2 should not be presented as independently covering those other clauses.
