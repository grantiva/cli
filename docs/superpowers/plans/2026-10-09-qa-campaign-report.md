# Cross-platform QA campaign — report

Date: 2026-10-09. Binary under test: grantiva 2.0.1 built from `c8dc86d` (Android support 3), with its runner 1.1.18-grantiva.7. Spec: `docs/superpowers/specs/2026-10-09-qa-campaign-design.md`. Plan: `docs/superpowers/plans/2026-10-09-qa-campaign.md`.

## What was built

- `grantiva/landmarks-demo` (private, `00fdc21`): the same Landmarks app twice, iOS (SwiftUI, scheme `Landmarks (UI Testing)`) and Android (Jetpack Compose, flavors free/paid), sharing one label contract, three launch-time environment variables (`LANDMARKS_SEED`, `LANDMARKS_CRASH_ON_LAUNCH`, `LANDMARKS_NOTE`), and thirteen Maestro-format flows that differ only in `appId`. `flows/README.md` documents the contract and the bait each flow exercises.
- `docs/superpowers/plans/2026-10-09-qa-feature-matrix.md`: 343 test rows (122 CLI, 116 iOS, 105 Android), each with an expected behavior cited to README, docs, CHANGELOG, or `--help`, and a scored result.
- `findings/`: raw findings per slice, the gate notes from building the apps, and a confirmer's triage per slice in which every finding was re-run or judged from source by a second agent.
- `docs/superpowers/plans/2026-10-09-qa-issues/`: 67 fix-ready briefs (26 CLI, 9 docs, 13 Android, 19 iOS), one per deduplicated bug, each with repro, expected with citation, actual output, evidence paths, suspected cause in `Sources/`, and acceptance criteria. `README.md` there is the index by severity. Hand a brief to an agent to open a PR.

## Matrix results

| Slice | Rows | Pass | Fail | Blocked | Host |
|---|---|---|---|---|---|
| CLI | 122 | 92 | 29 | 1 | 0 |
| iOS | 116 | 94 | 20 | 2 | 0 |
| Android | 105 | 79 | 22 | 2 | 2 |
| Total | 343 | 265 | 71 | 5 | 2 |

Blocked: `simulator cleanup` and the no-serial `emulator teardown` (would have destroyed other owners' devices), `console` reads needing credentials, and a row needing a test action the app lacks. Host: two rows need a physical Android device.

## Findings and briefs

Raw findings: 30 CLI + 14 docs, 36 iOS, 23 Android. After confirmation: every CLI and iOS finding reproduced; on Android one did not reproduce (a UIAutomator2 socket flake) and two were not bugs (behavior documented in CHANGELOG). Cross-slice duplicates were folded into one brief each.

| Severity | Briefs |
|---|---|
| crash | 1 |
| wrong-result | 21 |
| contract | 17 |
| ux | 17 |
| docs | 10 |
| enhancement | 1 |

Gate defects, found before the campaign started and confirmed on both platforms:

- Launch environment is dropped (A01, with iOS detail): on iOS `--env` does reach the app and only the flow-header `env:` is dropped; on Android `env:`, `--env`, and `launchApp.environment` are all dropped.
- `swipe` with `from:` ignores the element and swipes screen center while reporting success (A02).
- Bare `scroll` is unsupported although README lists it (C10).
- `simulator ensure --name` fails when the name carries no device model, contrary to README (I10).

Most consequential briefs beyond those:

- C01 (crash): `runner install` deletes `~/.grantiva/runner`, including other processes' lease locks, before extracting, and traps with exit 133 when the resource bundle is missing. This hit the campaign once at 13:55 and wiped a live runner.
- C02 (CLI-F04, AND-F03): the emulator ledger lists a hand-started emulator as Grantiva-owned, so `emulator teardown --all` would kill it. True on this host now.
- I02 (IOS-F27): `diff capture --no-build` ignores `simulator:` in `grantiva.yml` and drives the first booted device. During the campaign it attached to the user's iPhone 17 Pro for about four seconds. MCP `grantiva_vrt_capture` runs the same path.
- I01 (IOS-F24): two concurrent runs on different simulators share one WebDriverAgent derived-data path and kill each other; 3 of 3 paired runs failed, against README's concurrency promise.
- I08 (IOS-F09, IOS-F10): a run on a manually booted simulator takes a capacity slot and session teardown would shut it down. The user's iPhone 17 Pro has held a slot under a dead owner since before the campaign.
- I03 (IOS-F36): a failed `diff capture` leaves stale captures and `diff compare` then passes, a false pass.
- C03: the MCP server attaches to the newest keep-alive session on the machine regardless of project or platform.
- C04 (CLI-F08, AND-F06): `--report-dir`, `--timeout`, `--continue-on-failure` are ignored for screens-style runs.
- A03: config `application_id` overrides the ID of the APK actually built or passed, so the paid APK is installed but the free app is tested.
- C05 / C06: MCP VRT tools exec whatever `grantiva` is first on PATH; `grantiva_context` reports the wrong device.
- I05 / I06 (IOS-F30, IOS-F31): MCP `grantiva_tap` matches element name rather than label; `grantiva_type` calls an endpoint the agent does not serve.

## Doc discrepancies

Ten docs-severity briefs: C26, D02–D09 and I19 (D01 is contract severity). The spec's count of 19 MCP tools was stale; the binary registers 22.

## Host state

Baseline before: iPhone 17 Pro booted (pre-existing), emulator-5554 running (pre-existing). After: the same, with every `qa-*` simulator deleted and no runner, WebDriverAgent, or keep-alive session left behind. Two pre-existing anomalies were left in place as evidence: the capacity slot held by the iPhone 17 Pro under a dead owner, and the stale emulator-5554 ledger record. Android animation scales read 0/0/0 both before and after the campaign; the agents did not change them, and whether an earlier Grantiva run left them that way is unknown. One `simctl diagnose` started by a WebDriverAgent build was still running at the end and self-terminates on its 600 s timeout.

## Caveats

- Permission mode blocked two subagent actions (`gh repo clone` of the public source app, and the iOS agent's `git push`); the controller performed both under the approved plan.
- Three briefs point into the bundled grantiva-runner rather than this repo (shared WDA derived data, alert auto-accept, summary keyed by flow name) and cite the runner checkout at `~/Developer/maestro-runner`, which may be older than the bundled build.
- Flow 04 (discard alert) was flaky on iOS during the gate; its cause is written up in I04 as alert auto-accept and is not fully proven.
