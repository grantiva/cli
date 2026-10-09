# State in android-environment.md that `ci run` refuses Android

Severity: docs
Platforms: cli, android
Found by: CLI-DOCS-F09 (matrix rows CLI-117, CLI-108)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
docs/android-environment.md agrees with the behavior and docs/android.md §Captures and baselines: "`ci run` and remote
baselines refuse Android". Source: docs/android.md:46-50; CHANGELOG Unreleased Changed.

## Actual
docs/android-environment.md §CI (lines 20-22):
```
GitHub-hosted macOS runners cannot boot the Android emulator (no nested virtualization),
and Grantiva does not run on Linux. Android `ci run` needs a self-hosted Mac runner or a
developer machine.
```
but on any machine:
```
$ grantiva ci run --platform android
Android baselines are local only until the Grantiva backend supports platforms; use local baselines
```

## Repro
```
sed -n 18,24p docs/android-environment.md
cp -R fixtures/detect/gradle-only /tmp/d06 && cd /tmp/d06 && grantiva ci run --platform android; echo rc=$?
```

## Evidence
- docs/android-environment.md:20-22; docs/android.md:46-50; CHANGELOG.md:22
- findings/cli-triage.md (CLI-DOCS-F09 re-run)

## Suspected cause
docs/android-environment.md written ahead of backend platform support.

## Acceptance criteria
- docs/android-environment.md §CI says `ci run` refuses Android today, points to local `diff capture|compare|approve`,
  and keeps the self-hosted-Mac note for when it is supported.
