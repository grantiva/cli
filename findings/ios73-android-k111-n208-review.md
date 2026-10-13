# iOS 73 / Android K111 and N2-08 review

Scoped review against the round-3 matrix and candidate `8f2cff676b3c12e951478920fa20e600cdca4e29`.

## Material finding: D2-20(d) exposes a real force-teardown reporting defect

iOS attempt 73 is a valid live-session reproduction. `runner start --detach --json` exits 0 with PID 5064 and port 8191; the copied project session is `ready`; and an explicit-UDID hierarchy succeeds. The subsequent targeted `simulator teardown --udid <U> --force --json` exits 0, removes the project session, leaves PID 5064 absent, and removes the device runner home. The simulator remains booted, as expected for this directly created row device.

The JSON nevertheless has no `runnerSessionStopped` key, reports `reclaimed:false`, and has empty `processes` and `sessionFilesRemoved`. This is not a matrix mismatch. D2-20(d), README/help, and `SimulatorCommand.Teardown`'s own discussion explicitly require a runner session stopped by simulator teardown to be reported as `runnerSessionStopped`; the filesystem evidence separately proves the required session removal occurred.

The source explains the discrepancy. `SimulatorCommand.Teardown.run()` first calls `stopRunnerSessions`, which removes/stops the live runner and returns the stopped UDID. The `force` branch then calls `runForce(reaped:)`, but passes only helper-reap metadata. `runForce` encodes `ForceTeardownResult`, whose schema has no `runnerSessionStopped`; unlike the non-force branch, it never applies `marking(... stopped:)`. By the later live-process snapshot the runner is already gone, so `processes` is empty and `reclaimed` remains false despite the teardown having stopped the runner. Existing `testTeardownWithOnlyAnOwnerFileReportsRunnerSessionStopped` checks the non-force `SimulatorTeardownOutcome` marking helper, not the force result path exercised here.

D2-20 [ios] should remain incomplete/failing on leg (d), tracked by L73. The successful removal of the session and PID is useful cleanup evidence but cannot substitute for the required JSON contract.

## B3-K111 [android] and N2-01 [android]: supported; wrapper failure is an inventory bug

The five exact `--duration 4` commands all exit 0, and `ffprobe` reports `4.000000` seconds for all five files. Their JSON and verbose lines consistently retain the pre-hold timing (`recordedMilliseconds:0`, one idle frame at 0 ms), while the media duration is exactly four seconds.

The separate late-frame control is stronger for the trim-specific clauses: its JSON retains `recordedMilliseconds:5602` and `lastFrameMilliseconds:2801`, while the output movie is four seconds; `--frames-at 4000` exits 0 and resolves to the retained PNG at `frame-check/recording-frames/004000ms.png` with actual time 2801 ms. The wrapper's `frameImages=0` counted only depth one, while the JSON path and real nested PNG prove success.

Exact-head `MP4LastFrameHoldTests.testAnOverrunningTrackIsTrimmedToTheRequestedLength` pins the requested `stts`, `mdhd`, `tkhd`, `mvhd`, and `elst` changes and preserves the pre-trim end. `MP4LastFrameHoldFixtureTests.testAnOverrunningMovieIsTrimmedAndStillDecodes` pins post-trim decoding and endpoint frame extraction. The B3-K111 pass is supported; preserve the wrapper-one/depth-one limitation in provenance. The same runtime set also satisfies N2-01's five four-second recordings, pre-trim JSON timing, and 4000 ms endpoint-frame clauses, so N2-01 can be graded from this evidence.

## N2-08 [android]: supported

The read-only audit's three inputs hash exactly to the retained passing run, failing exact-negative run, and Android diff-capture JSON. It recursively checks 8, 3, and 8 step entries. All 19 contain `duration`; every observed value is a positive number, with none omitted or zero. `null` is allowed rather than required, so the absence of a null example does not weaken this runtime result. The exact-head README states the same rule for run and diff capture, and the source package pins candidate HEAD. The Android pass is supported.
