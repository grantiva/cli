# Skipped iOS install queries an absent app data container

Severity: contract
Component: cli / build install
Rows: D2-08 [ios] (with D2-07 status contract)
Candidate: CLI 8f2cff676b3c12e951478920fa20e600cdca4e29.
Status: evidence-backed triage during the incomplete round-3 coverage pass.

## Expected

`grantiva build install --no-build --no-launch` performs neither an install nor a launch and completes with the install-skipped result. D2-07 defines its JSON status as `skipped`; D2-08 requires the text `Done` line to say `(install skipped)`. The command must work whether the configured app is already installed or absent because `--no-launch` requests no operation on that app.

D2-08's main app-file forms are separate: with `--app-file`, `--no-build` skips only the build and the supplied app is installed. The failing case here is the row's no-app-file install-skipped control.

## Actual

On an owned simulator where the configured app is proven absent, the exact command prints `Skipping build and install (--no-build)` and then exits 1 with `NSPOSIXErrorDomain code=2` while looking up the absent app's data container. It never prints the promised `Done ... (install skipped, not launched)` line.

The identical command exits 0 when the app is already installed, prints the correct skipped completion, and leaves the same app container installed. The result therefore depends on an app that this mode promises not to install or launch.

## Evidence and repro

- iOS slice `findings/evidence/cov3-ios-attempt65/` preserves the row-created simulator, uninstall and absent-container probes, exact skipped command, stdout/stderr, and exit 1. `skipped.err` contains the POSIX missing-file error.
- The same attempt proves the D2-08 app-file paths behave correctly: build-install, run, and diff capture install the supplied simulator `.app`; unauthenticated `ci run` stops at the explicitly permitted authentication boundary.
- iOS slice `findings/evidence/cov3-ios-attempt65b/` is the installed-app control. Before and after probes name the same installed app container; `skipped.exit.txt` is 0 and `skipped.out` contains `Done — ... (install skipped, not launched)`.
- Independent review: CLI slice `findings/android-context-v4-x011-ios65-review.md`.

## Cause

Exact candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/BuildCommand.swift:187-193` correctly bypasses the not-installed launch refusal when `--no-launch` is set, but then unconditionally calls `dataContainerPath` at line 191 before computing the `.skipped` result. On iOS, that call invokes `simctl get_app_container ... data`, which fails when the app is absent.

The intended behavior is already represented by `completeInstall` and `completionMessage`: `--no-build --no-launch` maps to `.skipped` and the install-skipped/not-launched message. Existing encoding tests cover the skipped status shape but do not pin the absent-app execution path.

## Acceptance criteria

- `build install --no-build --no-launch` exits 0 for a valid target when the configured app is absent, performs no install or launch, and prints `Done ... (install skipped, not launched)` in text mode.
- Its JSON form reports `status: skipped` and does not fail while obtaining optional container metadata; document the absent value consistently with the existing iOS result shape.
- Preserve the current installed-app behavior, app-file installation behavior, and ordinary no-build-with-launch not-installed refusal.
- Add a focused `InstallCommand` test whose injected iOS device reports the app absent and whose data-container lookup would fail if called; assert the skipped command never requires that lookup. Retain the existing status/message and JSON key tests.
- Re-run the absent and installed controls and the D2-08 app-file build-install leg on an owned simulator.

