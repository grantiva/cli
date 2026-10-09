# Apply run's platform validation in doctor and init (ambiguous project, bad GRANTIVA_PLATFORM, other-platform flags)

Severity: contract
Platforms: cli, ios, android
Found by: CLI-F06, CLI-F11, CLI-F12 (matrix rows CLI-025, CLI-033, CLI-076)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
As for `run`: a directory with both an Xcode project and Gradle settings needs `--platform`; an invalid
`GRANTIVA_PLATFORM` is an error; "A flag from the other platform is rejected by name." Source: CHANGELOG Unreleased
(Added, Changed); help: run ("values: ios, android").

## Actual
- `doctor` in fixtures/detect/both requires both toolchains and fails on Android's JDK (`init`/`run` refuse correctly):
  ```
  Required JDK error No JDK found (JAVA_HOME or /usr/libexec/java_home)
    9 passed · 5 optional · 1 failed
  doctor-rc=1
  ```
- `GRANTIVA_PLATFORM=windows`: `doctor` exits 0; `init` exits 0 and writes `grantiva.yml`. `run` says
  `GRANTIVA_PLATFORM is "windows"; expected ios or android.`
- `init --platform android --scheme X` and `init --platform ios --application-id a.b` both exit 0 (`Created
  grantiva-android.yml` / `Created grantiva.yml`), dropping the flag. `run` says `--scheme is an iOS option, but this is an
  Android project (resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory).`

## Repro
From the qa-cli worktree (fixtures on branch qa/cli), each in a fresh copy:
```
cp -R fixtures/detect/both /tmp/c12a && cd /tmp/c12a && grantiva doctor; echo rc=$?
cd $(mktemp -d) && GRANTIVA_PLATFORM=windows grantiva doctor >/dev/null; echo rc=$?; GRANTIVA_PLATFORM=windows grantiva init; echo rc=$?
cp -R fixtures/detect/gradle-only /tmp/c12b && cd /tmp/c12b && grantiva init --platform android --scheme X; echo rc=$?
cp -R fixtures/detect/xcode-only /tmp/c12c && cd /tmp/c12c && grantiva init --platform ios --application-id a.b; echo rc=$?
```

## Evidence
- findings/evidence/cli/detect/detect.txt ([both] doctor)
- findings/evidence/cli/auth-logout-and-bad-platform.txt
- findings/evidence/cli/detect/platform-flags.txt (lines 97-101, 148-152)

## Suspected cause
Sources/GrantivaCLI/DoctorCommand.swift:34-49: `platformSelection` parses `GRANTIVA_PLATFORM` with
`Platform(rawValue:)` and silently ignores an invalid value (:41), and marks every detected platform required (:46).
Sources/GrantivaCLI/InitCommand.swift:27-30 and `platform(flag:detected:)` (:83) never read `GRANTIVA_PLATFORM`, and
`init` never calls `TargetOptions.checkFlags` (Sources/GrantivaCLI/TargetOptions.swift:43). Validation lives in
`PlatformResolver.resolve` (Sources/GrantivaCore/Platform/PlatformResolver.swift:24-35).

## Acceptance criteria
- Re-running the repro: `doctor` in both/ exits non-zero with "Found both ... Pass --platform ios|android or set
  GRANTIVA_PLATFORM." (or reports the second platform as advice, not Required); both `windows` cases fail with the
  `run` message; both `init` flag cases fail naming the flag, and write no file.
- GrantivaCLITests/DoctorSelectionTests: invalid env throws; both detected without flag throws (or required=false).
- GrantivaCLITests/InitAndroidTests: `--scheme` with `--platform android` and `--application-id` with iOS throw.
