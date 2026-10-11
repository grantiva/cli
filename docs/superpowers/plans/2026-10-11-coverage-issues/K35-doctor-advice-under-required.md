# `doctor` prints advisory toolchain checks under the "Required" heading

Severity: ux
Component: cli
Platforms: both (host checks: Xcode, Xcode Version, Booted Simulator, Android SDK, adb, emulator, JDK)
Rows: CLI-025, CLI-026, B-C12.1 (cli); original brief C12 (doctor-init-apply-run-platform-validation)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
When doctor treats a toolchain as advice (no project detected, or both an Xcode project and Gradle settings), the
check is shown as optional: not under "Required", consistent with the summary that counts it as optional.
- Brief C12 criterion 1 (B-C12.1): doctor in a both-projects directory exits non-zero "or reports the second platform
  as advice, not Required".
- README:330: doctor exits non-zero only "if a required check fails"; matrix CLI-026: "Both toolchains as advice".

## Actual
Both-projects directory, `DEVELOPER_DIR=/nonexistent`, no JDK (findings/evidence/cov-cli/CLI-025/doctor_failing_toolchains.out), exit 0:
```
  Required

    ● Xcode             /nonexistent does not exist
    ● Xcode Version     Could not determine Xcode version
    ● Booted Simulator  No simulator booted
    ✓ Android SDK       /Users/kyle/Library/Android/sdk
    ...
    ● JDK               No JDK found (JAVA_HOME or /usr/libexec/java_home)
  ...
  6 passed · 10 optional
```
Empty directory (CLI-026/doctor_nojava.out) shows the same, `6 passed · 9 optional`; `--json` gives those checks
`"status": "warning"` with `"section": "Required"`. The exit code is right (0); only the grouping contradicts it.
`Booted Simulator` (always a warning) sits under "Required" in every doctor run, including a single-platform project
(CLI-081/text.out).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k35
rm -rf /tmp/k35 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k35
mkdir /tmp/k35/both && cp -R /tmp/k35/ios/Landmarks.xcodeproj /tmp/k35/both/ && touch /tmp/k35/both/settings.gradle.kts
cd /tmp/k35/both
env -u JAVA_HOME DEVELOPER_DIR=/nonexistent grantiva doctor; echo "exit $?"
env -u JAVA_HOME DEVELOPER_DIR=/nonexistent grantiva doctor --json | jq -c '.[] | select(.status != "ok") | {name, section}'
mkdir /tmp/k35/empty && cd /tmp/k35/empty && env -u JAVA_HOME DEVELOPER_DIR=/nonexistent grantiva doctor
```
Today: `● Xcode`, `● Xcode Version`, `● JDK` under "Required"; JSON `"section":"Required"` with `"status":"warning"`.

## Evidence
- findings/evidence/cov-cli/CLI-025/commands.txt, doctor.out, doctor_failing_toolchains.out (rc=0)
- findings/evidence/cov-cli/CLI-026/commands.txt, doctor.out, doctor_nojava.out, doctor_nojava_rc.out
- findings/evidence/cov-cli/CLI-081/text.out (Booted Simulator warning under Required in an iOS project)

## Suspected cause
- Sources/GrantivaCore/Doctor/DoctorCheck.swift:17-21, :22: `Section` has only `required`, `project`, `cloud`, and
  every check defaults to `.required`.
- Sources/GrantivaCore/Doctor/DoctorRunner.swift:13-31: `runAllChecks(platforms:required:)` downgrades toolchain checks
  to `.warning` when `required == false` (checkXcode :56-71, checkXcodeVersion :73-85, Android checks :140-182) but
  never changes their section; checkBootedSimulator (:87-107) is always a warning in the Required section.
- Sources/GrantivaCLI/DoctorCommand.swift:38-63 (`platformSelection`) returns `required: false` for both-detected and
  nothing-detected directories.
- Sources/GrantivaCore/Doctor/DoctorFormatter.swift:30-37 prints sections in fixed order by `section`.

## Acceptance criteria
- Re-running the repro: with `required == false`, the toolchain checks print under an advisory heading (for example a
  new `Toolchain (optional)` section, or "Optional") and not under "Required"; `--json` gives them that section value.
- `Booted Simulator` is not under "Required" in any mode (it is never an error).
- A detected single-platform project (`--platform ios` or an Xcode-only dir) still lists failing Xcode checks under
  "Required" with `✗`, exit 1 (CLI-081 unchanged).
- The summary counts and exit codes are unchanged.
- GrantivaCoreTests/DoctorTests: `runAllChecks(platforms: [.ios, .android], required: false)` returns no check with
  `section == .required` and `status != .ok`; GrantivaCLITests/DoctorSelectionTests covers the both-detected case.
