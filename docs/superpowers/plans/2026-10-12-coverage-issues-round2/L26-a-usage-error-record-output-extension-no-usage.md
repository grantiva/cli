# `record --output` with the wrong extension exits 64 but prints no `Usage:` / `See … --help` lines, unlike every other exit-64 `record` error

Severity: contract
Component: cli
Platforms: both (iOS `.mov`, Android `.mp4`; checked without a device)
Rows: EXTRA-04 [cli] (side finding of CLI-144 [cli])
Regresses/extends: K41 (negative timeout missing value) and K42 (teardown usage error prefix), fixed by CLI #192.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

Split: cluster M19 has two root causes. This is half a. Half b (`--device`/`--emulator` exits 1 with `Invalid
argument:`) is L26-b.

Triage note: the code says the missing Usage lines are deliberate (`RecordCommand.swift:200-202`: "ExitCode keeps the
usage line out of it"), because the check needs the platform resolved from the config. The cluster map allows either
fix: print the Usage lines, or document the exception. The owner should pick one.

## Expected
K41/K42 established one shape for a usage error: exit 64, a plain `Error: <message>` (no `Invalid argument:`), then
`Usage: grantiva <command> …` and `  See 'grantiva <command> --help' for more information.`. Every other exit-64 `record`
error has that shape: `--duration 0`/`-1` (CLI-143), a missing `--duration` (CLI-102/103), malformed `--frames-at`, and
B-C14.2.

## Actual
Four extension errors, each exit 64 with one line and no Usage (findings/evidence/cov2-cli/CLI-144/*.err):
```
Error: --output must end in .mov on iOS (simctl records QuickTime); got a.mp4. Try a.mov.
Error: --output must end in .mov on iOS (simctl records QuickTime); got a. Try a.mov.
Error: --output must end in .mp4 on Android (screenrecord records MPEG-4); got a.mov. Try a.mp4.
Error: --output must end in .mp4 on Android (screenrecord records MPEG-4); got a. Try a.mp4.
```
Same command, other usage error (findings/evidence/cov2-cli/CLI-143/rec.err):
```
Error: --duration must be greater than zero
Usage: grantiva record [--json] [--verbose] [--quiet] [--platform <platform>] [--simulator <simulator>] [--emulator <emulator>] [--device <device>] --duration <duration> [--output <output>] [--frames-at <frames-at>]
  See 'grantiva record --help' for more information.
```
Deterministic.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l26a && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l26a
cd /tmp/l26a/ios && grantiva record --duration 2 --output a.mp4; echo "exit=$?"       # exit=64, no Usage lines
cd /tmp/l26a/android && grantiva record --duration 2 --output a.mov; echo "exit=$?"   # exit=64, no Usage lines
cd /tmp/l26a/ios && grantiva record --duration 0; echo "exit=$?"                      # exit=64 with Usage lines (reference)
```
No device is reached. The check runs before any boot.

## Evidence
- findings/evidence/cov2-cli/CLI-144/ios_mp4.err, ios_noext.err, and_mov.err, and_noext.err, commands.txt
- findings/evidence/cov2-cli/CLI-143/rec.err, findings/evidence/cov2-cli/CLI-102/rec.err (the shape the others use)
- docs/superpowers/plans/2026-10-11-coverage-issues/K41-negative-timeout-missing-value.md, K42-teardown-usage-error-prefix.md

## Suspected cause
`Sources/GrantivaCLI/RecordCommand.swift:198-205`: `outputExtensionProblem` (`:86`) runs in `run()`, after
`platformOptions.loadConfig()`. On a problem it logs the message and throws `ExitCode.validationFailure`, which gives 64
and suppresses ArgumentParser's usage block. `validate()` (`RecordCommand.swift:44`) cannot see the platform because it
comes from the config or directory.

Fix options:
- (a) Throw a `ValidationError`-shaped error from `run()` that ArgumentParser formats with usage. For example, call
  `Self.exit(withError: ValidationError(problem))`, or build the usage text with `Self.helpMessage`/`usageString()` and
  print it under the message.
- (b) In `validate()`, reject an extension that fits neither platform (`a`, `a.avi`), and keep the platform-specific
  mismatch in `run()` as a documented exception (README `record` section).

## Acceptance criteria
- (a) `record --output a.mp4` on iOS and `--output a.mov` on Android exit 64 with the message, then the same `Usage:`
  and `See 'grantiva record --help'` lines as `--duration 0`. Or (b) README's `record` section states that the extension
  check prints no usage block, and an extension valid on neither platform gets the full shape.
- No `Invalid argument:` prefix in either case.
- Tests: GrantivaCLITests/RecordCommandTests, run the command through the parser/test harness used by the K42 tests with a
  temp iOS project and `--output a.mp4`. Assert exit code 64, the first line equal to the message, and (for option a) a
  second line starting `Usage: grantiva record`.
