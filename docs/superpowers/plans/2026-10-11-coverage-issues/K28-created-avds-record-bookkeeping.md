# `emulator teardown` skips the created-AVD prune when it refuses, and claims to drop a record that never existed

Severity: wrong-result
Component: cli
Platforms: android (Android-only)
Rows: AND-109 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/android.md:184-186: "AVDs `ensure` created are listed in `~/.grantiva/android/created-avds.json`; ... `ensure`,
`delete`, `sessions` and `teardown` drop names whose AVD no longer exists on disk." So after an out-of-band
`avdmanager delete avd -n cov-android-2`, any `teardown` call, including one that refuses its serial, drops the name.
And `teardown --force` on a serial with no record does not say it dropped one.

## Actual
`sessions`, `ensure`, `delete` and a successful `teardown` prune the name (AND-109/01-03, 05). A refused teardown does
not (AND-109/04):
```
["cov-android","cov-android-3x","cov-android-2"]      <- before; cov-android-2 deleted with avdmanager, `grep -c` 0
0
rc=1
["cov-android","cov-android-3x","cov-android-2"]      <- after: still listed
Error: Invalid argument: emulator-5598 was not started by Grantiva (see `grantiva emulator sessions`). Pass --force to kill it anyway.
```
`teardown --serial emulator-5598 --force` for a serial that was never recorded or attached (AND-109/05):
```
emulator-5598 was already gone; dropped its record.
rc=0
["cov-android","cov-android-3x"]
```
(The prune ran this time, so the AVD list is right; the message claims a serial record that did not exist.)

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=fix-k28; unset GRANTIVA_API_KEY
cd /tmp
grantiva emulator ensure --name fix-k28 --no-boot
cat ~/.grantiva/android/created-avds.json; echo
avdmanager delete avd -n fix-k28
grantiva emulator teardown --serial emulator-5598; echo "rc=$?"
cat ~/.grantiva/android/created-avds.json; echo          # today: fix-k28 still listed
grantiva emulator teardown --serial emulator-5598 --force; echo "rc=$?"   # today: "...was already gone; dropped its record."
cat ~/.grantiva/android/created-avds.json; echo
```
(Use a serial no emulator is using; `emulator-5598` was free in the slice.)

## Evidence
- findings/evidence/cov-android/AND-109/04.out, 04.err (refused teardown leaves the name), 05.out (unrecorded `--force`),
  01-03.out (other commands prune), 06.out, commands.txt

## Suspected cause
- Prune skipped on refusal: `Sources/GrantivaCLI/EmulatorCommand.swift:131-139` (`Teardown.teardown`) calls
  `emulators.teardown(serial:force:)` first; it throws the "not started by Grantiva" error
  (Sources/GrantivaCore/Android/EmulatorManager.swift:466-470) before `pruneCreatedAVDs()` at EmulatorCommand.swift:137
  runs. (`pruneCreatedAVDs` itself is EmulatorManager.swift:376-392, function at :381.)
- Message: `EmulatorCommand.swift:174` prints `"\(serial)\(name) was already gone; dropped its record."` whenever
  `killed` is false; `EmulatorTeardownOutcome` already carries `recorded` (EmulatorManager.swift:497), which is false here.

## Acceptance criteria
- In the repro, after the refused teardown (exit 1, same error) `created-avds.json` no longer lists `fix-k28`.
- `teardown --force` of an unrecorded, unattached serial prints `emulator-5598 is not attached and has no record;
  nothing to do.` (or similar), exit 0; with a stale record it keeps today's "dropped its record" text.
- `--json` outcomes keep `recorded` and `killed` accurate.
- GrantivaCLITests (EmulatorCommandTests): a refusing teardown still calls the prune; the outcome renderer prints the
  no-record wording when `recorded == false && killed == false`.
