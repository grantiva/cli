# iOS attempts 30–31 review

## Important finding: IOS-057 pass overclaims cleanup evidence

IOS-057 requires the runner, WDA, and `simctl diagnose` to be reaped, plus session/owner removal and lease release. Attempt 30 directly supports only part of that contract:

- the exact U1 lock and matching global session sidecar exist during the hold and are absent afterward;
- the original `grantiva` process group is empty afterward;
- the command exits cleanly after SIGINT.

It does **not** prove that WDA or `simctl diagnose` processes were present and then reaped. `signal.json` records `sawLogStream:false`, and `during-process-group.txt` contains only the top-level grantiva process. The final log has abundant `[log]` content, proving log content/wiring for the run, but content is not a process-identity snapshot and cannot establish cleanup of the enumerated helpers. `PROVENANCE.md` correctly narrows this to absence of an orphan after the log stream ended before the hold; the ledger row instead claims the complete IOS-057 criterion.

Remove the IOS-057 pass or qualify it as partial until focused before/after process evidence covers runner, WDA, and `simctl diagnose`. Lock disappearance supports lease release, and the global sidecar disappearance supports session cleanup; neither substitutes for the named process checks.

## Attempt 30 rows otherwise supported

- **IOS-061:** supported. The default run exits 0 and preserves 1,573 `[log]` lines; neither forbidden `getpwuid_r` nor `Filtering the log data` banner appears.
- **IOS-062:** supported. `logs-predicate.command.txt` contains the exact predicate without `--logs`; stderr explicitly narrates `Streaming simulator logs (predicate: subsystem == "com.kylebrowning.Landmarks")`, proving the flag implied streaming. The flow passes and no emitted `[log]` line violates the filter. Exact-head `RunCommand.startLogStream` and `IOSPlatform.logStream` pass the explicit predicate to `simctl log stream --predicate`; this is a wiring/source join, not an invented positive app-log count.
- **IOS-063:** supported. All three commands exit 0 and retained `[log]` counts are debug 30,181, info 4,891, default 1,575, satisfying the required ordering. Exact-head platform source passes the selected value to `log stream --level`.

The separate failure stream is useful durability evidence but is not needed to inflate these row criteria.

## Attempt 31 rows supported

IOS-005/006/007/008 match every matrix clause:

- IOS-005's newly absent-before UUID is created Shutdown under `--no-boot`; stdout contains only that UUID.
- IOS-006's new JSON is complete and `created:true`; bare-name reuse returns the identical UUID, its own iPhone 17 type and iOS 26.0 runtime, and `created:false`.
- IOS-007 exits nonzero with the exact inference/`--device-type` guidance, and the post-ensure snapshot contains no rejected name.
- IOS-008's concurrent calls both exit 0, return one identical newly absent-before UUID, split `created:true`/`false`, and simctl contains exactly one device with that name.

The initial `simulator teardown --force` calls are correctly disclosed as non-deleting (`reclaimed:false`) and are not used as cleanup proof. The separate `attempt31-cleanup` package validates each current UUID/name against `before.json`, deletes only those three attempt-owned devices, records exit 0 for all three, and `after.json` omits all three UUIDs. This closes campaign hygiene without affecting the row verdicts or touching owner devices.

No other unsupported grade or provenance problem was found in attempts 30–31.
