# `--device` with `--emulator` exits 1 with `Error: Invalid argument: …` and no Usage, while every other mutually-exclusive pair exits 64 with the plain form and Usage

Severity: contract
Component: cli
Platforms: android (the flags are Android's; checked without a device)
Rows: EXTRA-07 [cli] (with CLI-045 and CLI-145 [cli], whose texts were matrix corrections; the exit-code mismatch is this defect)
Regresses/extends: K42 (teardown usage error prefix) and K43 (platform flag rejection wording), fixed by CLI #192.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

Split: cluster M19 has two root causes. This is half b. Half a (`record --output` extension errors without Usage) is
L26-a.

## Expected
K42: a usage error reads `Error: <message>` with exit 64 and the usage lines, and no `Invalid argument:`. Two flags that
cannot be combined are the same class of error wherever they occur. `simulator teardown --session-id/--udid` and
`emulator teardown --serial/--all` already behave this way.

## Actual
`record --device a --emulator b` (Android project), exit 1 (findings/evidence/cov2-cli/CLI-145/and_dev_emu.err):
```
Error: Invalid argument: --device and --emulator are mutually exclusive; pass one.
```
`simulator teardown --udid <x> --session-id x`, exit 64
(findings/evidence/cov2-cli/B2-K42/td___udid________________________.err):
```
Error: --session-id and --udid are mutually exclusive; pass one.
Usage: grantiva simulator teardown [--json] [--verbose] [--quiet] [--session-id <session-id>] [--udid <udid>] [--force]
  See 'grantiva simulator teardown --help' for more information.
```
`run --device/--emulator` (CLI-045) behaves like `record`, and `emulator teardown --serial/--all` (CLI-147) like
`simulator teardown`. Deterministic.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l26b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l26b && cd /tmp/l26b/android
grantiva record --duration 2 --device a --emulator b; echo "exit=$?"     # bug: exit=1, "Invalid argument:", no Usage
grantiva run --device a --emulator b; echo "exit=$?"                     # bug: same
grantiva runner start --device a --emulator b; echo "exit=$?"            # bug: same
grantiva emulator teardown --serial emulator-9999 --all; echo "exit=$?"  # reference: exit=64, plain, Usage
```

## Evidence
- findings/evidence/cov2-cli/CLI-145/and_dev_emu.err, commands.txt (exit=1)
- findings/evidence/cov2-cli/B2-K42/td___udid________________________.err, commands.txt (exit=64)
- findings/evidence/cov2-cli/CLI-045/, findings/evidence/cov2-cli/CLI-147/
- docs/superpowers/plans/2026-10-11-coverage-issues/K42-teardown-usage-error-prefix.md, K43-platform-flag-rejection-wording.md

## Suspected cause
- Three copies of the check throw `GrantivaError.invalidArgument` at run time:
  `Sources/GrantivaCLI/TargetOptions.swift:58-60` (run, diff capture, build install and the other target-taking
  commands), `Sources/GrantivaCLI/RecordCommand.swift:112-114`, `Sources/GrantivaCLI/DriverCommand.swift:178-180`
  (`runner start`). `invalidArgument` maps to exit 1 with the `Invalid argument:` label.
- The teardown pairs throw ArgumentParser's `ValidationError` from `validate()`
  (`Sources/GrantivaCLI/SimulatorCommand.swift:121`, `Sources/GrantivaCLI/EmulatorCommand.swift:178`), which gives exit
  64 and the usage block.
- The exclusivity check needs no platform, so it can move into each command's `validate()` (or a `TargetOptions.validate()`
  that ArgumentParser runs for the option group) as a `ValidationError`. Note the order change: on an iOS project,
  `--device a --emulator b` then reports exclusivity before the other-platform flag error (`TargetOptions.swift:55-57`).
  That is acceptable but should be pinned.

## Acceptance criteria
- `record`, `run`, `diff capture`, `build install` and `runner start` with `--device a --emulator b` exit 64 and print
  `Error: --device and --emulator are mutually exclusive; pass one.` followed by the command's `Usage:` and `See … --help`
  lines. No `Invalid argument:`.
- The check runs before any config load or device resolution (it fails in a directory with no project too).
- The three duplicate run-time checks are removed (one helper).
- Tests: GrantivaCLITests/TargetOptionsTests and RecordCommandTests, `parseAsRoot(["run", "--device", "a", "--emulator",
  "b"])` (and the record/runner start equivalents) throws a `ValidationError` with that message. The K42 harness asserts
  exit code 64 for one of them.
