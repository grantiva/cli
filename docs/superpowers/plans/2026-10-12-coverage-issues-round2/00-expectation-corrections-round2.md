# Expectation corrections, round 2 coverage (applied 2026-10-12)

Matrix: `docs/superpowers/plans/2026-10-12-round2-coverage-matrix.md`. Each corrected expected cell ends with `(corrected round 3)`. IDs and other cells are unchanged. Sources: slice results `findings/cov2-{cli,ios,android}-results.md`, cluster map §Expectation corrections, README at c65fc17.

| row / brief | what the slice found | correction |
|---|---|---|
| CLI-003 | 170/172 help pages identical; `runner_stop`, `simulator_teardown` differ by L04 (#198) sentences added after the corpus was regenerated (7593fab) | Marked `(corrected round 3: corpus regenerated at c65fc17)`; no other change. The corpus itself still has to be regenerated at c65fc17 |
| D2-47 | 15/17 pages match; same two pages, same reason | Same marker as CLI-003 |
| CLI-011 | statuses are ok/warning/error; README:439 uses `"error"` (K62); the `"fail"` filter prints nothing | Expected filter is `select(.status == "error")` |
| CLI-025 | `run` errors correctly; `doctor` reports the Platform finding under Advisory and exits 0 (brief C12's allowed alternative, B-C12.1; K35) | `doctor` expected to report and exit 0 |
| CLI-038 | exit 1 before any build with `Error: No screens or flows configured in grantiva.yml`; no `Invalid argument:` label (`nothingToRunMessage`, K52) | Label removed from expected text |
| CLI-085 | prints `grantiva-runner 1.1.28-grantiva.11` (bundled runner, #199) | Literal `.9` becomes `.11` |
| N2-02 | same `.10` vs `.11`; doctor's Runner check and `runner install` do print the installed stamp | Literal `.11`; "none does today" replaced by the recorded fact |
| CLI-087 | no-session message uses backticks and no `Invalid argument:` (K46) | Expected text replaced with the K46 message, exit 1 |
| CLI-143 | `record --duration 0` exits 64 with usage line (K41; B2-K41) | Expected `Error: --duration must be greater than zero`, exit 64 |
| CLI-145 | other-platform rejections use the long form (K43); `--device`/`--emulator` reads `... mutually exclusive; pass one.` | Expected texts updated. Exit-1 vs 64 inconsistency is product defect M19, not corrected here |
| CLI-161 | README:98 now `<runner home>/versions/<stamp>/devices/<udid>` (K63), matches disk | `<runner version>` becomes `<stamp>` |
| B-C18.1 (row) | missing-config texts are `GrantivaConfig.missingFileMessage` (K52) | Row expected text uses K52 wording |
| B-C18.1 (brief C18) | criterion 1 quotes `No grantiva-android.yml here. ...` | C18 brief annotated; criterion 1 withdrawn in favour of K52 wording |
| IOS-122 | input device was session-owned (cov2-ios-1); session-less run correctly refused with guidance (K70); unowned half passes | Expected covers both halves; input must be an unowned, simctl-booted device for the no-slot half |
| IOS-145 | first `diff compare` exits 1 with `? No baselines: 5 new screens` (K89, README) | Expected: capture and approve succeed, first compare exits 1, second passes |
| MCP-025 | invalid script rejected as expected; `type "x"` with no focused field stops isError (K102) | Expected: final tree only for a script without `type` or with a prior focus tap; no-focus `type` refuses |
| MCP-026 | Android, same as MCP-025 (K102/D2-37) | Same correction |
| N-01 | `runner stop` releases the keep-alive fully; ready file stays `passed` (written once, README:83, :419) | `interrupted` only if the stop lands before flows finish |
| B2-K14 (row) | same as N-01 | Row text: ready file unchanged once terminal |
| B2-K14 (brief K14) | criterion asks for `interrupted` after completed flows | K14 brief annotated; criterion withdrawn |
| B2-K68 (row) | after `kill -9`, `reclaimed: true` but `leaseReleased: false`: K79 makes the runner exit with its parent, nothing holds the flock | Bullet 2 text: `reclaimed: true`; `leaseReleased` true only if the runner still held the lease |
| B2-K68 (brief K68) | bullet 2 stale after K79 | K68 brief annotated; not a product defect |
| AND-107 | `launchApp` passes; first assert fails with `app_crash` (B2-L02 requires first-assert outcome) | "at `launchApp` or at the first step after it". Run-2 plain `assertion` miss is a product defect under L02/L06 |
| AND-040 | same crash path with `--env LANDMARKS_CRASH_ON_LAUNCH=1` | Same wording |
| B-A01.1 (row) | same for 99-crash half; qa-note, 09, 10 pass | Row wording as above |
| B-R01.3 (row) | stock set 12/12; 99-crash fails at first assert | Row wording as above |
| Briefs R01, A01 | criteria say 99-crash fails at `launchApp` | Both annotated; criterion withdrawn in favour of "at `launchApp` or at the first step after it" |
| AND-223 | four bare scrolls end at Landmark 28 on Android (N-03/B2-K07 correction) | `Landmark 30` becomes `Landmark 28` |

## Not a correction

| row | note |
|---|---|
| CLI-083 | Not an expectation error: the no-booted-simulator half cannot be produced while any simulator is booted. Expected text left unchanged. It goes to the Blocked list, to be batched with B-C21.1 in a window with no booted simulators. The advisory-and-exit-0 part held for the checks that could be produced |

## Annotated briefs (each gains a "Correction (round 2 coverage, 2026-10-12)" section)

- `docs/superpowers/plans/2026-10-11-coverage-issues/K14-runner-stop-misses-keepalive.md`
- `docs/superpowers/plans/2026-10-11-coverage-issues/K68-teardown-free-udid-reports-reclaimed.md`
- `docs/superpowers/plans/2026-10-10-regression-issues/R01-android-inputtext-replaces-field.md`
- `~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/C18-run-names-platform-missing-config.md`
- `~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/A01-android-launch-env-as-intent-extras.md`
