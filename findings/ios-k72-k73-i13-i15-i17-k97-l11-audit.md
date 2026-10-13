# iOS build, hierarchy, test-error, crash, and SIGHUP audit

Exact candidate source is `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff67`; exact runner source is `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b` at `fd9d8e8`. Quarantined historical imports are excluded.

## Scheme detection: B-I13.1, B-I13.2, B2-K72

Attempt 26 supplies the multi-scheme error: `08-no-scheme-two-project-schemes.err` exits nonzero and names both `Landmarks` and `Landmarks (UI Testing)`. Exact-head `ProjectResolutionTests` pins several-scheme rejection, silent one-scheme resolution, legacy cache re-detection, and `testACachedSingleSchemeIsDroppedWhenTheProjectGainsASecond`.

The current runtime set does not contain the required one-scheme project first/cached successful builds followed by restoring the second scheme and observing the error. Therefore all three rows remain **partial**: their multi-scheme and source clauses are covered, but the one-scheme runtime and cache-transition input are missing. One device-free scratch sequence can close B-I13.1, B-I13.2, and B2-K72 together.

## Bundle mismatch: B2-K73

Exact-head `InstallCommandTests` semantically pins the mismatch error, both IDs and Info.plist path, and verifies no data-container lookup with the wrong ID. Current attempt 65 contains NSPOSIX container failures for other absent-app inputs, but no retained current command uses `build install --no-launch --bundle-id <other> --json`; it cannot establish K73. The matching-ID/current behavior is well covered elsewhere. B2-K73 remains **partial**, missing only the explicit mismatched-ID runtime call.

## Hierarchy errors: B-I15.1 and B-I15.2

B-I15.1 is fully supported as currently graded: attempt 29 has the exact one-line 0.01-second port timeout; attempt 85b has the guarded absent-app no-build failure before flow execution and restores the app.

B-I15.2's source clause is covered by exact `HierarchyCommandTests`, which pin `.timedOut` and `.cannotConnectToHost` messages with port/remediation and reject raw NSURLErrorDomain text. The current runtime evidence proves `.timedOut`, but this audit found no current hierarchy call made after a live agent dies that produces the cannot-connect form. B-I15.2 remains **partial** unless an existing current dead-agent hierarchy artifact can be indexed; source semantics do not replace that explicit runtime input.

## MCP test failure: B-I17.1 and B-I17.2

Both rows are fully supported by current attempt 6 `MCP-029/fallback-transcript.txt`. `grantiva_test` returns `isError: true`, includes the exact xcodebuild `not currently configured for the test action` line, an `Errors:` section, and a bounded `Output (last 4 lines):` tail. The successful build/run immediately before it stays concise. Exact-head `BuildToolsTests` pins extraction of error lines, failing test names, bounded tail bytes/lines, and short success output. B-I17.1 and B-I17.2 can be graded **pass**.

## Crash classification: B2-K97

B2-K97 is **fully supported** by the exact current-round join. Attempt41 runs the stock `.maestro/coverage/02-exact-negative.yaml`; `fail-report/flows/flow-000.json` identifies `02-exact-negative` and records the failed exact-visible command as `error.type: "assertion"`. Attempt45 `crash-1-report/flows/flow-000.json` records the crashed-app wait as `app_crash`, with the bundle ID and “is not running, possibly crashed” in the message, while `crash-1.exit.txt` is 1. Attempt90 `json-report/flows/flow-000.json` independently records the custom missing element as `element_not_found`. These are the row’s three distinct classifications; no attempt95 run is needed.

## B3-L11

B3-L11 is fully supported by attempts 89f and 89g plus exact source. Attempt 89f sends SIGHUP directly to the nohup keep-alive runner and proves it remains alive and hierarchy still succeeds; its wrapper’s later stop is not the successful stop control. Attempt 89g proves normal concurrent stop/reap and separately that SIGKILL of a passed keep-alive runner makes Grantiva exit 1 in 0.576 seconds naming SIGKILL, with sidecars gone. Exact `ChildProcessTests` pin default signal disposition and watchdog behavior.

macOS `ps` does not offer the requested `ignored` output keyword. The ledger appropriately discloses that limitation and uses the row's observable behavioral requirement—survive direct SIGHUP and continue serving hierarchy—plus exact source semantics. This is not a missing runtime variant and does not warrant another device run. Attempt 89h separately proves parent-HUP survival for N2-18; it is corroboration, not a substitute for attempt 89f's direct-runner signal.
