# Round 2 coverage report

**Campaign:** full-coverage campaign (spec `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`), round 2 coverage pass (plan `docs/superpowers/plans/2026-10-12-round2-coverage-pass.md`). Resume point for any agent: `docs/superpowers/plans/2026-10-12-campaign-handoff.md`.

**Under test:** grantiva 2.1.0 from `main` c65fc17 (`~/.grantiva-qa/bin/grantiva` with its bundle), bundled grantiva-runner 1.1.28-grantiva.11 (runner `grantiva/main` 1be68db; stamp `1.1.28-grantiva.11+android-drivers-2`; WDA caches `sim-ios{26.0,26.2,26.4,27.0}-iphone-wda16.12.8-r1`, 26.2/26.4 copies of 26.0). This build carries the round-2 fix wave (runner #17–#20, CLI #189–#199: every round-1 brief K01–K111 plus the smoke addendum L01–L04). Runner home `~/.grantiva-qa/runner`. Demo apps: landmarks-demo `main` b3f046f. Devices: `cov2-ios-1` (iPhone 17, iOS 26.0), `cov2-ios-2` (iPhone 17, iOS 27.0), AVD `cov2-android` (API 35, default software-rendered config); all created and deleted by the slices.

**Matrix:** `docs/superpowers/plans/2026-10-12-round2-coverage-matrix.md`, 1084 rows: the 886 round-1 rows (IDs unchanged, corrected expectations marked), 127 `B2-K`/`B2-L` rows quoting each round-2 brief's acceptance criteria, 20 `N2`, 3 `S2`, 48 `D2` (docs/help diffs). Every row has a verdict in exactly one slice (checked by the task reviewers).

## Results per slice

| slice | branch (head) | rows | pass | fail | fail (expectation triage) | blocked | n/a | extra fail rows |
|---|---|---|---|---|---|---|---|---|
| CLI (`findings/cov2-cli-results.md`) | cov2/cli 33c3a4e | 365 | 335 | 7 | 13 | 6 (5 handed to iOS; CLI-153 Global Constraint) | 4 | EXTRA-01..07 |
| iOS (`findings/cov2-ios-results.md`) | cov2/ios 7bed447 | 442 (+39 `@27.0` repeats, +5 handed CLI rows) | 415 (+39 +4) | 17 (+1 CLI-049) | 6 | 4 | 0 | — |
| Android (`findings/cov2-android-results.md`) | cov2/android 8885a21 | 414 | 372 | 31 | 6 | 3 | 2 | AND2-OBS-01..07 |
| **total (matrix rows)** | | **1084 (+44)** | **1122 + 43** | **56 + 14 extras** | **25** | **13 → 7 real** | **6** | |

Android re-ran its load-sensitive rows on a quieter host (load 5–13) inside its fix round; re-runs are `<ID> rerun` lines beside the originals. Four IDs failed in two slices (N2-13, S2-03, B2-K105, B2-K103/K16 family), and the 94 fail rows collapse to **41 distinct defects** (`00-cluster-map-round2.md`; M25 withdrawn as an expectation correction).

**Blocked (7 real):** AND-002 (only 1 GB+ system images uninstalled), AND-012 (`teardown --all` forbidden), AND-088 (no credentials), IOS-018 (`simulator cleanup` would touch non-campaign simulators), B-C21.1 and CLI-083 (need a host with no booted simulator — the owner's iPhone 17 Pro stays booted), B-I06.2 (`/wda/keys` not observable), N-08 (needs root), CLI-153 (`init`'s default simulator resolves to the owner's iPhone 18 Pro). The five CLI device rows were run by iOS (4 pass, CLI-049 fail).

**n/a:** AND-069, AND-070 (physical device), CLI-152 (no second grantiva install), B-D05.2 (no CHANGELOG), B-I19.2, B-I19.3 (doc-only fix).

## Stock sets (Step 1)

- iOS 26.0 and 27.0: build+install pass; stock 12/12 + 5 screens on both; WDA cache hit, no first-time build; `99-crash` fails fast with `app_crash` (~140 ms).
- Android: stock 12/12 + 5 screens on the third attempt — attempts 1–2 failed under host load 98–394 (`UIAutomator2 not ready after 30s`, then a system ANR dialog); `99-crash` fails with `app_crash` but at the first assert, not at `launchApp` (L02's expected outcome); `exact:` screens clean; inputText appends; swipe `from:` opened the row 5 of 10 (7 of 10 on re-run — L07); `build build` never boots.

## Review Focus verdicts

1. **No regression in rows that passed in round 1.** Mostly holds. Round-1 passes that now fail: AND-210 (`doubleTapOn` registers as two taps, 3/3 on the quiet host), AND-224 (`scrollUntilVisible` stops short, 1/3), AND-213 (unbounded focused-element lookup under load 68; passes 3/3 quiet), N-12 (blank Home capture, 3/3). All four are new round-3 briefs.
2. **Round-2 brief acceptance criteria hold (B2-K/B2-L rows).** 127 rows: most pass. Not holding: K16 (runner stop JSON lacks `port`/`bundleId`/`applicationId`), K17 (session capture `duration: 0`), K37 (MCP build takes a user's simulator — booted the owner's iPhone 18 Pro), K60 (approve names only the first missing screen), K90-a/K90-b/K105 (staged paths and `exact` in summaries), K100.2 (Android has no "starting" state), K103 (`session.json` vs `runner start --json` key names), K106 (Android teardown leaves temp dirs after kill -9), K107-b (no fresh-home guard in CI), K111 (overrun untrimmed, intermittent), L02 (timing targets missed; one crash missed outright), L05, L06, L07 (open, confirmed). L01, L03, L04 hold.
3. **Cross-platform consistency.** Does not hold: X-022/B2-K17 (capture durations), N2-15/OBS-04 ("releasing simulator" on Android), N2-13 (`extendedWaitUntil`/`waitForAnimationToEnd` pass against a dead app on both drivers), D2-31 (Android frames still strings), S2-03 (no summary on a failing run, both platforms).
4. **README flow commands per platform.** Exercised on 26.0, 27.0 and Android. Failing: `doubleTapOn` (two taps; `{point}` rejected), `scrollUntilVisible` short (Android), swipe `from:` 7/10 (L07), `extendedWaitUntil`/`waitForAnimationToEnd` on a dead app, sub-flow staged path printed (K105), screens summary drops `exact`.
5. **MCP server.** Does not hold: `grantiva_build` default-simulator takeover (M01), unknown-tool/`name`-required texts break the prefix contract (M08), a cancelled call still returns a late result (M07), `emulator_boot` says "booted" for a running AVD (M39), `grantiva_context` message names the wrong directory (MCP-046), `resources/read` edge cases per K100.2.

## Triage

Cluster map: `docs/superpowers/plans/2026-10-12-coverage-issues-round2/00-cluster-map-round2.md` — 94 fail rows → 41 clusters (M01–M24, M26–M42), each a brief `docs/superpowers/plans/2026-10-12-coverage-issues-round2/L<nn>-<slug>.md` (L08–L48; L = 7 + M for M ≤ 24, then L32+ for M26+). Highest severity: M04 (SIGHUP kills the runner under nohup — crash), M01 (MCP build takes a user's simulator), M02 (Android `init` default AVD without ownership warning), M03 (failing run prints no stdout summary), M38 (blank Home capture), M40 (app lost after `emulator teardown`), M17 (WDA `waitForAnimationToEnd` passes on a crashed app).

### Expectation corrections (no product change)

`00-expectation-corrections-round2.md`: 25 rows (13 CLI, 6 iOS, 6 Android incl. the four crash-at-first-assert rows AND-107/AND-040/B-A01.1/B-R01.3 superseded by L02's expected outcome; AND-223 stale Landmark 30; MCP-026 vs K102) and brief corrections K14 (ready file write-once), K68 (bullet 2 stale after K79), C18, R01/A01 (crash caught at `launchApp` or the first step after it). Matrix rows carry `(corrected round 3)`.

### Briefs

BRIEFS_TABLE

## Host state after cleanup

- `xcrun simctl list devices | grep -c cov2` = 0; `adb devices` empty; no `cov2-` AVDs; Grantiva ledgers (`created-avds.json`, `started.json`) `[]`; `/tmp/grantiva-sessions` empty; no device homes under the QA runner home's `versions/*/devices/`.
- Owner devices: `iPhone 17 Pro` stayed booted and was never commanded. `iPhone 18 Pro` (FE441EE5) was **booted by the iOS slice's MCP build** (B2-K37.2, the product defect M01) and is left booted for the owner; its `~/.grantiva/simulator-capacity/sessions.json` record (ephemeral slot of session cov2-ios, deletable by a session teardown) was removed by the controller (backup kept). `Pixel_8_API_35` never booted.
- Pre-existing leftovers not created by this round: ~699 lock files under `~/.grantiva/runner/locks` (K107-b history), an `emulator-5598.lock` from an earlier session, 35+ `reports/<timestamp>` dirs from `runner start`.

## Process notes

- Slices ran in parallel; host load from other processes reached 46–394 during parts of the Android run, so Android re-ran its load-sensitive rows (re-run table in the Android task report; outcomes in the cluster map's §Load-sensitive).
- Three slip disclosures, none affecting other sessions' processes: CLI slice named the iOS slice's simulator in one `ci run` that failed on auth first (CLI-168); Android slice ran `pkill -P` on its own loop pid once (AND-035); iOS slice sent `grantiva_build` without a simulator before learning the default (MCP-031 — the row that booted the owner's device).
- Help corpus pages changed by L04 were regenerated (a2876461) after the CLI slice flagged them (CLI-003/D2-47 → corpus corrections).
- Expectation-correction rows are not defects; the matrix is corrected so round 3 grades the intended behaviour.

## Exit criterion

VERDICT_LINE
