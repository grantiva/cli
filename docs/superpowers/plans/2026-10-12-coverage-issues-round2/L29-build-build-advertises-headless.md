# `grantiva build build --help` offers `--headless` (and the other device-boot flags) although the command never boots or resolves a device

Severity: docs
Component: cli
Platforms: both (help text; the flag is described as Android-only, and Android `build build` never boots). Logical, no load dependence.
Rows: EXTRA-06 [cli] (side finding of D2-27 [cli])
Regresses/extends: extends K54 (MCP `grantiva_build` must never boot an AVD, fixed in #195) and K27 (headless rule, fixed in #189): help hygiene for the same "build never boots" rule.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
`docs/android.md:54` (c65fc17): "`grantiva build build` only compiles: it never resolves or boots a device, so
`emulator:` does not apply to it." Its help therefore offers no option that only affects booting or choosing a device to
run on. `--headless` ("Boot an emulator without a window") belongs on `build install`, `run`, `ci run`, `diff capture`,
`diff compare` and `emulator ensure`, which do boot.

## Actual
`build build --help` lists `--headless` with the same text as the commands that boot.
findings/evidence/cov2-cli/D2-27/helps.out:1-4:
```
## build build
 --headless Boot an emulator without a window (Android).  GRANTIVA_EMULATOR_HEADLESS=1 or CI=true does the  same; otherwise a booted emulator gets a window, even  when stdout is not a terminal.
## build install
 --headless Boot an emulator without a window (Android).  GRANTIVA_EMULATOR_HEADLESS=1 or CI=true does the  same; otherwise a booted emulator gets a window, even  when stdout is not a terminal.
```
Source read (not run): the same option group also gives `build build` `--emulator` ("AVD name to use, booting it if
needed") and `--allow-device-settings`, which are accepted by `checkFlags` on Android and then ignored by `run()`.

## Repro
No device needed.
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"; unset GRANTIVA_API_KEY
grantiva build build --help | grep -n -E -- '--headless|--emulator|--allow-device-settings'
grantiva build install --help | grep -c -- '--headless'   # 1, correct here
```

## Evidence
- findings/evidence/cov2-cli/D2-27/helps.out, findings/evidence/cov2-cli/D2-27/commands.txt
- findings/cov2-cli-results.md rows D2-27 (pass) and EXTRA-06 (fail)

## Suspected cause
- `Sources/GrantivaCLI/BuildCommand.swift:28`: `BuildOnlyCommand` declares `@OptionGroup var target: TargetOptions`.
- `Sources/GrantivaCLI/TargetOptions.swift:27-37` puts `--emulator`, `--device`, `--allow-device-settings` and
  `--headless` in that one group; `--headless` is at `:36`.
- `BuildOnlyCommand.run()` (`BuildCommand.swift:33-62`) uses only `target.device` (to read the ABI of an attached
  device, `:57`). `target.androidOptions` (`:35`, which carries `headless`/`allowDeviceSettings`) never reaches a boot, and
  `target.emulator` is read nowhere on this path.

## Acceptance criteria
- `grantiva build build --help` does not list `--headless` (and, unless the command starts to use them, not `--emulator`
  or `--allow-device-settings`); `build install`, `run`, `ci run`, `diff capture`, `diff compare` and `emulator ensure`
  still do.
- `grantiva build build --headless` (and `--emulator X`, if hidden too) either still parses for compatibility while
  hidden from help (`ArgumentHelp(visibility: .hidden)`), or fails with the usual unknown-option usage error (exit 64);
  pick one and say so in docs/android.md next to the `:54` sentence.
- `--device` on `build build` keeps its documented ABI role.
- Regenerate the `findings/help` corpus page `build_build.txt`.
- Test in `GrantivaCLITests` (next to the existing help/options tests, e.g. `BuildCommandTests.swift`): render
  `BuildOnlyCommand.helpMessage()` and assert it contains no `--headless`; render `InstallCommand.helpMessage()` and
  assert it does.
