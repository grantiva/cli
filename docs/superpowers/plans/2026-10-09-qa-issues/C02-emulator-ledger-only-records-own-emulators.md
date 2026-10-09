# Never record, or later tear down, an emulator Grantiva did not boot itself

Severity: wrong-result
Platforms: cli, android
Found by: CLI-F04 (matrix rows CLI-016)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
Only emulators Grantiva started are listed, so `emulator teardown --all` touches nothing else. Source: CHANGELOG Unreleased
("Emulators Grantiva boots are recorded in ~/.grantiva/android/started.json"); help: emulator teardown.

## Actual
`~/.grantiva/android/started.json` held a record for a user-started emulator. `emulator sessions --json`:
```
[
  {
    "adbState" : "device",
    "avd" : "Pixel_8_API_35",
    "pid" : 19482,
    "processAlive" : false,
    "serial" : "emulator-5554",
    "startedAt" : 813271244.347498
  }
]
```
The real emulator-5554 is qemu pid 49817, started Oct 7 outside Grantiva. `~/.grantiva/android/emulator-5554.log` ends in
`FATAL | Running multiple emulators with the same AVD is an experimental feature`: Grantiva spawned a second copy of the
same AVD on port 5554, it died at once, and the record stayed. Because the AVD name matches, `emulator teardown --all`
would `adb emu kill` the user's emulator.

## Repro
1. Start an AVD yourself: `emulator -avd Pixel_8_API_35 -port 5554 &`, and wait for `adb devices` to list it.
2. Make adb briefly not list it (`adb kill-server`), then immediately boot the same AVD through Grantiva:
   ```
   grantiva run --platform android --emulator Pixel_8_API_35 --no-build
   ```
   (or call `EmulatorManager.boot(avd:)` from a test with a fake `adb.devices()` that returns `[]`).
3. `grantiva emulator sessions --json` lists emulator-5554 with `processAlive: false`, `adbState: device`.
4. Do not run `emulator teardown --all` on a machine whose emulator you need; it would kill it.

## Evidence
- findings/evidence/cli/json/emulator_sessions.out
- findings/cli.md CLI-F04 (quotes `started.json` and `emulator-5554.log`); findings/cli-triage.md CLI-F04

## Suspected cause
Sources/GrantivaCore/Android/EmulatorManager.swift:210-221: `boot(avd:)` picks a port from `adb devices` alone
(`choosePort`, :127) and registers the record (:219) before boot. `waitForBoot` (:238) sees `sys.boot_completed=1` on the
existing emulator at that serial before it notices the spawned pid died, so the record is never removed. The stale-record
guard in `teardown` (:350-355) drops a record only when the AVD differs.

## Acceptance criteria
- Re-running the repro leaves no record for emulator-5554, and `emulator teardown --all` does not kill it.
- `choosePort` also skips ports whose console port is bound; the record is written only once the spawned pid is the
  process answering on the serial (or removed if the pid exits, even if the serial answers).
- `teardown` refuses a record whose pid is dead without `--force`, regardless of AVD name.
- GrantivaCoreTests/EmulatorManagerTests: a fake adb answering `boot_completed=1` for a serial while the spawned pid is
  dead asserts `boot` throws and `started.json` has no record; a teardown test asserts a dead-pid record is not killed.
