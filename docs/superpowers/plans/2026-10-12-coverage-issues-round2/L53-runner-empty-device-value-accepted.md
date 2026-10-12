# `grantiva-runner --device ""` is treated as a real device and fails with the `--team-id` error instead of rejecting the empty value

Severity: minor
Component: runner
Platforms: ios
Rows: none yet; found during the round-3 Task 8 repack (WDA cache build) when a build step passed an empty device
Regresses/extends: K42 (usage-error shape), L15 (argument-failure wording)
Binary: grantiva-runner 1.1.28-grantiva.12 (grantiva/main 2d1b625)

## Expected
An empty `--device` value is an argument failure: `Error: Invalid argument: '--device' must not be empty.` (or the runner's
equivalent one-line usage error), exit 64, before any device lookup or signing check runs.

## Actual
The empty string is taken as a physical-device identifier and the run fails later with the real-device `--team-id`
signing error, which points the user at code signing instead of at the empty flag.

## Reproduce
`grantiva-runner --platform ios --device "" test <flow>` with no `--team-id`.

## Fix direction
Validate `--device`, `--udid` and `--serial` values as non-empty (and, for simulators, UDID-shaped) at flag parsing;
one test per flag. Also check the CLI never forwards an empty device value (CLI side: refuse with the Invalid argument
line). Schedule: round 4 unless a `B3-L`/`N3` row fails on it.
