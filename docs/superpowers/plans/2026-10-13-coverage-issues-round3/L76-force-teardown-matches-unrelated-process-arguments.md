# Force teardown matches unrelated processes whose arguments mention Grantiva and a UDID

Severity: destructive process-selection defect
Component: iOS simulator force teardown
Rows: IOS3-OBS-01 (round-3 side finding)
Candidate: CLI `8f2cff676b3c12e951478920fa20e600cdca4e29`.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

`grantiva simulator teardown --udid <UDID> --force` reclaims processes which actually hold that simulator: `grantiva-runner`, WebDriverAgent's `xcodebuild`, `simctl diagnose`, or a live `grantiva run`. It must not signal an unrelated process merely because its argument list mentions both the Grantiva binary path and the UDID.

## Actual

A row-owned inert Python process ran only `time.sleep(120)`. Its two unused positional arguments were `/Users/kyle/.grantiva-qa/bin/grantiva` and the UDID of a new, shutdown disposable simulator. It never accessed the simulator.

Force teardown exited 0 but reported this process as `kind: "grantiva"`, `killed: true`, and `reclaimed: true`. The Python process exited `-2` from SIGINT. The disposable simulator remained shutdown and was deleted under an exact-UDID cleanup guard after capture.

An earlier live-run harness independently exposed the same collision: force teardown interrupted the Python orchestrator which was waiting to capture teardown output, even though the true foreground Grantiva process ran in a separate process group and emitted its own normal teardown notice. The inert reproduction removes the runner, device access, and orchestration ambiguity.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt82/summary.json`
- `sleeper-command.json`, `sleeper.pid`, `ps-before.txt`, and `ps-after.txt` preserve the unrelated process's exact executable, arguments, process group, and removal.
- `teardown-command.json`, `teardown.out`, and `teardown.err` preserve the exact force invocation and JSON classification.
- `created.json`, `before.json`, `cleanup-before.json`, and `cleanup-after.json` preserve the new shutdown simulator and guarded deletion.
- `all-files.sha256` preserves the immutable artifact set.
- Independent source/evidence review: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-cli/findings/ios78b-reaper-android-s201-d238-review.md`.

## Cause

Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Simulator/SimulatorReaper.swift:118-140` searches the entire lowercased command line. After finding the UDID, its fallback classifies a process as `.grantiva` whenever the command contains `"grantiva "` or ends in `grantiva`. This matches a non-Grantiva executable when a Grantiva path appears only as an argument.

The stricter helper in the same file at lines 149-159 already parses the first executable token and accepts only basename `grantiva` or `grantiva-runner`, but live force discovery does not use that check. Existing `SimulatorReaperTests` cover an unrelated `sleep` command which contains neither trigger argument, so they do not exercise this collision.

## Acceptance criteria

- Process classification requires the actual executable to be Grantiva for `.grantiva`; a command such as `python3 helper.py /path/to/grantiva <UDID>` is excluded.
- Preserve matching of an actual `grantiva run ... --simulator <UDID> --keep-alive` process.
- Preserve the existing runner, WebDriverAgent, and `simctl diagnose` classifications and their device-specific guards.
- Add a focused `SimulatorReaperTests` semantic assertion using a synthetic process snapshot with an unrelated executable and Grantiva/UDID positional arguments; assert force teardown does not report, signal, or mark reclaimed from that process alone.
- Add a positive sibling assertion for an actual Grantiva executable so argument filtering cannot disable intended recovery.

