# `emulator teardown --force` after a killed run leaves that run's staged-flow and report temp dirs behind and does not list them

Severity: ux
Component: cli
Platforms: android (1 of 1 run, load 5.7; logical: the Android teardown has no temp-dir step). iOS passes (B2-K106 [ios]: both dirs listed under `temporaryDirectoriesRemoved` and gone).
Rows: B2-K106 [android]
Regresses/extends: K106 (docs/superpowers/plans/2026-10-11-coverage-issues/K106-reclaim-leaves-killed-run-temp-dirs.md) incomplete for Android; fixing PR #190 covered `simulator teardown` only.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K106 criteria, applied to the Android row (`run --keep-alive` killed with `kill -9`, then
`emulator teardown --serial <s> --force --json`): afterwards `comm` of the run's temp dirs against what remains prints
nothing, and the `--json` result lists the removed paths. A preserved `--report-dir`, and temp dirs of a live run, are
never removed.

## Actual
findings/evidence/cov2-android/B2-K106/01.out:
```
keep-alive on emulator-5556 pid 82216: passed
/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-96934240-445C-4A72-B507-85B037082E3A
/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-report-E0C92521-8E77-4478-8377-8D6858495305
[
  {
    "avd" : "cov2-android-2",
    "killed" : true,
    "recorded" : true,
    "runnerSessionStopped" : false,
    "serial" : "emulator-5556"
```
followed by `left:` and the same two paths. The emulator is killed; both temp dirs of the killed run stay and the
document has no field for them. (`runnerSessionStopped: false` is right: after K79 the runner died with its killed
parent.)

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l35
unset GRANTIVA_API_KEY
rm -rf /tmp/l35 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l35 && cd /tmp/l35/android
sed -i '' 's/^emulator: .*/emulator: fix-l35/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l35)
grantiva build install --device "$SERIAL" --no-launch
T=$(python3 -I -c 'import tempfile;print(tempfile.gettempdir())')
ls -d "$T"/grantiva-* 2>/dev/null | sort > /tmp/l35/before.txt
nohup grantiva run --device "$SERIAL" --no-build --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/l35/ready > /tmp/l35/ka.out 2> /tmp/l35/ka.err &
KA=$!; for i in $(seq 1 180); do [ -f /tmp/l35/ready ] && break; sleep 1; done
ls -d "$T"/grantiva-* | sort > /tmp/l35/during.txt; comm -13 /tmp/l35/before.txt /tmp/l35/during.txt > /tmp/l35/run-dirs.txt; cat /tmp/l35/run-dirs.txt
kill -9 $KA; sleep 2
grantiva emulator teardown --serial "$SERIAL" --force --json
ls -d "$T"/grantiva-* 2>/dev/null | sort | comm -12 - /tmp/l35/run-dirs.txt     # expected: empty
grantiva emulator delete --name fix-l35
```

## Evidence
- findings/evidence/cov2-android/B2-K106/01.out, 01.cmd, commands.txt, ka.out, ka.err, ka.ready
- findings/evidence/cov2-ios/B2-K106/ (iOS pass, for the expected JSON shape)

## Suspected cause
- Runs record their temp dirs in the device's lease claim on both platforms: `RunnerSession.swift:111`, `:132`, `:403`,
  `:467` call `SimulatorLease.recordTemporaryDirectory` (`SimulatorLease.swift:283-288`), and the Android lease is taken
  with the serial as its key (`RunnerSession.swift:92`).
- Only `SimulatorReaper` reads it back: `SimulatorReaper.swift:216` (`removeTemporaryDirectories(of:)`, `:247`) and the
  `temporaryDirectoriesRemoved` field (`:45`).
- `EmulatorManager.teardown(serial:force:)` (`Sources/GrantivaCore/Android/EmulatorManager.swift:590-632`) never reads
  the claim: it stops UIAutomator2, removes forwards, `emu kill`s and drops the provenance record. Its outcome
  (`EmulatorTeardownOutcome`, `:37-51`) has no temp-dir field, and `EmulatorCommand.swift:147-160` adds only
  `runnerSessionStopped`. The lease file for the serial is not removed either (not observed; source read).

## Acceptance criteria
- After the repro, the final `comm` prints nothing and the `--json` outcome lists both paths under
  `temporaryDirectoriesRemoved` (same key as iOS); the text output names them, as `simulator teardown` does
  (`SimulatorCommand.swift:292`).
- The same holds for a killed `run` without `--keep-alive`, and for `emulator teardown --all --force`.
- A preserved `--report-dir` and the temp dirs of a live claim (owner pid alive) are never removed; the reaper's
  `grantiva-` prefix and temp-root checks are reused, not copied.
- The serial's stale lease file is removed with the claim.
- Tests in GrantivaCoreTests/EmulatorManagerTests.swift: `testForceTeardownRemovesTheKilledRunsTempDirectories` (claim
  under a temp lease directory naming two `grantiva-…` dirs under a temp root, owner pid dead → removed and listed) and
  `testForceTeardownKeepsTempDirectoriesOfALiveOwner`; GrantivaCLITests/EmulatorCommandTests.swift: the `--json`
  outcome encodes `temporaryDirectoriesRemoved`.
