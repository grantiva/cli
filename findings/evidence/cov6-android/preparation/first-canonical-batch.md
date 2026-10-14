# Candidate5 Android first canonical entries

Preparation only. `$CLI` is the frozen QA binary, `$SCRATCH` and all device variables remain root-allocated placeholders. Each execution must use the approved collector, JDK 21/SDK PATH, both runner-home variables set to the same allocated fresh home, `GRANTIVA_SESSION_ID=candidate5-android`, and `GRANTIVA_API_KEY` unset.

The matrix begins with AND-106–108, but those rows require a booted primary and frozen APK while AND-001 requires the primary AVD to be absent. Root must schedule the lifecycle leg first, then the intro leg, and publish verdicts in canonical key order. No old runtime result or grade transfers.

## AND-106

- Matrix line: 535
- Literal command family: `run --no-build`
- Preconditions: stock set
- Required clause: 12/12 pass incl. 02-favorite (swipe reveals Remove) and 03-edit (append), exit 0 (brief R01, R02; plan Task 5 Step 1)
- Prepared invocation: `$CLI run --no-build --report-dir $SCRATCH/and106-report`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-107

- Matrix line: 536
- Literal command family: `run --flow`
- Preconditions: `.maestro/99-crash.yaml`
- Required clause: Fails with `app_crash` (`crashed on launch: java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH`) at `launchApp` or at the first step after it; the dead app must not pass any step. Record time to failure (brief R01 criterion 3; B2-L02 requires the first-assert outcome; fix round 1 re-grade, was M25) (corrected round 3)
- Prepared invocation: `$CLI run --no-build --flow .maestro/99-crash.yaml --report-dir $SCRATCH/and107-report --ready-file $SCRATCH/and107-ready.json`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-108

- Matrix line: 537
- Literal command family: `diff capture`
- Preconditions: five configured screens
- Required clause: 5/5; Lakes and Detail are the right screens (docs/android.md:68-76)
- Prepared invocation: `$CLI diff capture --no-build`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-001

- Matrix line: 543
- Literal command family: `emulator ensure`
- Preconditions: `--name cov-android` (AVD missing, image installed)
- Required clause: Creates (`avdmanager create avd -d pixel_8`), boots, prints only the serial (docs/android.md:166, 173-175)
- Prepared invocation: `$CLI emulator ensure --name $CANDIDATE5_ANDROID_PRIMARY_AVD`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-002

- Matrix line: 544
- Literal command family: `emulator ensure`
- Preconditions: `--name cov-android-2 --system-image <an image not installed>`
- Required clause: Installs it with `sdkmanager`, then creates and boots; `blocked` if no small uninstalled image is available (docs/android.md:173)
- Prepared disposition: BLOCKED unless root permits SDK download and identifies a small uninstalled image; otherwise inventory-only proof under carried no-download constraint
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-003

- Matrix line: 545
- Literal command family: `emulator ensure`
- Preconditions: same name again
- Required clause: Reuses; same serial (help: emulator_ensure.txt)
- Prepared invocation: `$CLI emulator ensure --name $CANDIDATE5_ANDROID_PRIMARY_AVD`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-004

- Matrix line: 546
- Literal command family: `emulator ensure`
- Preconditions: `--name cov-android-2 --no-boot`
- Required clause: Created, not booted; stdout is the AVD name (docs/android.md:167)
- Prepared invocation: `$CLI emulator ensure --name $CANDIDATE5_ANDROID_EXTRA_AVD --no-boot`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-005

- Matrix line: 547
- Literal command family: `emulator ensure`
- Preconditions: `--headless`
- Required clause: No window (`-no-window`) (help: emulator_ensure.txt)
- Prepared invocation: `$CLI emulator ensure --headless  # cwd prepared config selecting extra AVD`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-006

- Matrix line: 548
- Literal command family: `emulator ensure`
- Preconditions: no `--name`, config `emulator: cov-android`
- Required clause: Uses the configured AVD (help: emulator_ensure.txt)
- Prepared invocation: `$CLI emulator ensure  # cwd config emulator: $CANDIDATE5_ANDROID_EXTRA_AVD`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-007

- Matrix line: 549
- Literal command family: `emulator ensure`
- Preconditions: no `--system-image`, no config value
- Required clause: `system-images;android-35;google_apis;arm64-v8a` (docs/android.md:174-175)
- Prepared invocation: `evidence join to fresh AND-004 creation stdout/stderr plus extra config.ini; no duplicate mutation`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-008

- Matrix line: 550
- Literal command family: `emulator ensure --json`
- Preconditions: none
- Required clause: Valid JSON record (help: emulator_ensure.txt)
- Prepared invocation: `$CLI emulator ensure --json  # cwd prepared config selecting authenticated extra AVD`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.

## AND-009

- Matrix line: 551
- Literal command family: `emulator sessions`
- Preconditions: `--json`
- Required clause: Lists the emulators Grantiva started (docs/android.md:168)
- Prepared invocation: `$CLI emulator sessions --json`
- Capture: candidate identity before command; exact argv/env/cwd/times/exit/raw streams; host load; device/AVD/process ownership before and after where applicable; clause-specific artifacts; immutable first verdict.
