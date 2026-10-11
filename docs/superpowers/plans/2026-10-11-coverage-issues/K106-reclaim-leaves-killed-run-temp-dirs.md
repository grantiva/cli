# `simulator teardown --force` after a `kill -9`'d run leaves that run's staged-flow and report temp dirs behind

Severity: ux (re-graded from wrong-result: README:441-446 lists what the reclaim removes and temp dirs are not on the list; the effect is a disk leak in `$TMPDIR` that grows with every killed run, holding reports and captures)
Component: cli
Platforms: both (the staging and report temp dirs come from RunnerSession, shared by both platforms; the reaper code is iOS-specific (`simulator teardown`), and `emulator teardown --force` was not checked)
Rows: IOS-016 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9
Triage note: the matrix row's expected result (processes, `reclaimed`, records kept, device homes) passed in full;
this is an extra observation recorded in the same row. If the team decides temp dirs are out of scope for the
reclaim, the fallback is a note in README "Reclaiming a simulator".

## Expected
A run that was killed outright cannot clean up after itself, and `simulator teardown --udid <UDID> --force` exists for
exactly that case (README:430-446: it "kills whatever is holding that simulator …, releases the lease, removes the
killed runner's keep-alive session files, and clears any stale capacity record"). Its job is to restore the state a
clean exit would have left. A clean exit removes the staged-flow dir `$TMPDIR/grantiva-<UUID>` and, without
`--report-dir`, the report dir `$TMPDIR/grantiva-report-<UUID>` (RunnerSession.swift:357, :427-430), so the reclaim
should remove the killed run's copies too.

## Actual
`findings/evidence/cov-ios/IOS-016/teardown.out` shows the killed runner's command line, which names both dirs
(`--output …/grantiva-report-60A86E91-… … /var/folders/…/grantiva-34AFF040-…/0/01-browse.yaml`), and reports
`"reclaimed"`, `"leaseReleased" : true`, the device home removed and the cov-ios record kept, exit 0. After it, both
dirs still exist (`findings/evidence/cov-ios/IOS-016/leftover-tmp.txt`):
```
/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-34AFF040-7468-4B8B-90A5-17AC9D4247D6
/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-report-60A86E91-F429-4BD8-89F8-F38118C2FF3C
```
Nothing in the `--json` result mentions them.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k106
unset GRANTIVA_API_KEY
rm -rf /tmp/k106 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k106 && cd /tmp/k106/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k106 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
ls -d "$TMPDIR"grantiva-* 2>/dev/null | sort > /tmp/k106/before.txt
grantiva run --simulator "$UDID" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k106/ka.ready > /tmp/k106/ka.log 2>&1 &
KA=$!; until [ -f /tmp/k106/ka.ready ]; do sleep 1; done
kill -9 $KA
grantiva simulator teardown --udid "$UDID" --force --json > /tmp/k106/teardown.json; echo "exit $?"
ls -d "$TMPDIR"grantiva-* 2>/dev/null | sort | comm -13 /tmp/k106/before.txt -
grantiva simulator teardown --session-id fix-k106; grantiva simulator delete --name "fix-k106 iPhone 17"
```
Today: exit 0, then `comm` prints one `grantiva-<UUID>` and one `grantiva-report-<UUID>` dir.

## Evidence
- findings/evidence/cov-ios/IOS-016/leftover-tmp.txt (surviving dirs)
- findings/evidence/cov-ios/IOS-016/teardown.out (reclaim JSON; the runner command line names both dirs), commands.txt
- findings/evidence/cov-ios/IOS-016/procs-after-teardown.out (processes gone, sessions dir empty)
- findings/cov-ios-results.md rows IOS-016, B-I09.1

## Suspected cause
- Sources/GrantivaCore/Runner/RunnerSession.swift:353-357 (staged-flow dir, removed by `defer`) and :409-430
  (temp report dir, removed by `defer` when no `--report-dir`); the single-flow capture path has the same pattern at
  :60-64 and :76-93. `defer` never runs after SIGKILL.
- Nothing durable records these paths: `KeepAliveOwner` (KeepAliveSessionStore.swift:40-60) holds udid, pids,
  project dir and platform; `SimulatorLeaseClaim` (SimulatorLease.swift:12-25) holds pid, udid, start time, runner pid
  and keep-alive.
- `SimulatorReaper` force teardown (SimulatorReaper.swift:170-230) reaps processes, releases the lease, clears
  capacity records, removes session files and device homes, and has nothing to say about temp dirs. Its process
  snapshot does see the runner's `--output` and flow path arguments, but parsing command lines would be fragile.

Fix direction: record the run's temp dirs in the lease claim (every run takes a lease, RunnerSession.swift:47, :336,
so non-keep-alive runs are covered as well), have the reclaim read the claim before `forceRelease` and remove those
dirs only when their owning pid is dead, and list them in the `--json` result (e.g. `tempDirectoriesRemoved`).

## Acceptance criteria
- After the repro, `comm` prints nothing; the `--json` result lists the two removed paths.
- The same holds for a killed run without `--keep-alive`.
- A preserved `--report-dir` is never removed by the reclaim.
- Temp dirs of a live run on another simulator, or of a run whose pid is alive, are never removed.
- Unit tests in `GrantivaCoreTests/SimulatorReaperTests.swift`:
  `testForceTeardownRemovesTheKilledRunsTempDirectories` (claim written with two temp dirs under a test temp root,
  owner pid dead → removed and listed) and `testForceTeardownKeepsTempDirectoriesOfALiveOwner`; and in
  `SimulatorLeaseTests.swift`, a round-trip test for the new claim field.
