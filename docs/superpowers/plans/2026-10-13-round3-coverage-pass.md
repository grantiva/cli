# Round 3 Coverage Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Exercise every grantiva subcommand, flag and MCP tool (minus `auth` and `console`) with a real flow on iOS 26.0, iOS 27.0 and Android API 35 against the release binary built after the round-3 fix wave, record a verdict and evidence per matrix row, and turn every finding of any severity into a brief for the round-4 fix wave, or declare the campaign clean.

**Architecture:** Task 0 (orchestrator) verifies the test home after the round-3 smoke and creates the slice worktrees. Task 1 is done at dispatch: the round-3 matrix is the round-2 matrix with results cleared, the round-2 expectation corrections kept (`(corrected round 3)`), the `B2-*` rows kept as regression rows, one or more `B3-L<nn>` rows per round-3 brief quoting its acceptance criteria (as the fix-wave rulings changed them), `N3-nn` rows for every behaviour the fix wave added, and the re-run rules for the rows round 2 left blocked. Tasks 3-5 run the CLI, iOS and Android slices in parallel, one row at a time, with real flows and captured evidence. Task 6 merges the slice branches, triages every non-pass row into a brief, and writes the round report with the exit-criterion verdict.

**Tech Stack:** grantiva CLI 2.1.0 release build at `~/.grantiva-qa/bin/grantiva` (CLI main 8f2cff67 (after the .13 bundle PR #206 and the L63 PR #207), grantiva-runner 1.1.28-grantiva.13); landmarks-demo (SwiftUI + Compose, Maestro-format flows); Xcode 27.0 with iOS 26.0/27.0 runtimes; Android SDK 35 emulator.

**Spec:** `docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md`. Inputs: the round-2 coverage plan (`2026-10-12-round2-coverage-pass.md`, the template of this one), the round-2 matrix (`2026-10-12-round2-coverage-matrix.md`, 1084 rows, corrected), the round-2 report (`2026-10-12-round2-coverage-report.md`), the round-3 briefs L05–L52 (with the splits L26-a/b, L38-a/b, L42-a/b) and K111 (`docs/superpowers/plans/2026-10-12-coverage-issues-round2/`, `2026-10-11-coverage-issues/K111-*.md`), the round-2 cluster map and expectation corrections (`00-cluster-map-round2.md`, `00-expectation-corrections-round2.md`), the round-3 fix-wave plan and its Rulings table (`2026-10-13-round3-fix-wave.md`), the fix-wave ledger (`findings/ledgers/2026-10-13-round3-fix-wave-ledger.md`, for the rulings made during execution), and the round-3 smoke (`findings/round3-smoke.md`, written by fix-wave Task 9).

## Global Constraints

- Binary: `/Users/kyle/.grantiva-qa/bin/grantiva` with its `grantiva_GrantivaCore.bundle` beside it; `export GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"`; never `swift build` in a slice; never another grantiva binary (a copy of this binary in a scratch dir, as rows B3-L28 and N3-11 make, is the same binary).
- Runner home: `export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"` in every shell (a clone of the owner's home, upgraded to `1.1.28-grantiva.13+android-drivers-2` with the four WDA caches `-wda16.12.8-r1` (confirm from task-8-report: `r2` if Task 8 rebuilt them)). Never unset it; never write under `~/.grantiva/runner`; `GRANTIVA_API_KEY` unset; `export GRANTIVA_SESSION_ID=cov3-<slice>`. Rows that name a scratch home (IOS-018, B3-L27, B3-L28, N3-11) set it for that row's commands only. Since L08 a home other than the default keeps its own `<runner home>/simulator-capacity/` ledger: the QA home's ledger is `~/.grantiva-qa/runner/simulator-capacity/`, not `~/.grantiva/simulator-capacity/`.
- Devices: iOS slice owns `cov3-ios-26` (iPhone 17, iOS 26.0) and `cov3-ios-27` (iPhone 17, iOS 27.0), created with `simulator ensure --name <n> --device-type "iPhone 17" --runtime "iOS 26.0"` (`"iOS 27.0"`); extra simulators `cov3-ios-3`/`-4` only inside a row that needs them, deleted before the row ends. Android slice owns AVD `cov3-android` (`emulator ensure --name cov3-android`, default software-rendered config; plus `cov3-android-2` inside a row that needs it). CLI slice has no devices; rows that need one are run by the iOS or Android slice instead (the matrix assigns them). Every device command names its device (`--simulator`/`--udid`/`--device`/`--serial`).
- Standing device rules: never touch `iPhone 17 Pro` (B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C), `iPhone 18 Pro` (FE441EE5-…), AVD `Pixel_8_API_35` or any device the slice did not create; if `adb devices` or `xcrun simctl list devices booted` lists a device you did not create, leave it alone (reading the list is fine). Never `teardown --all`, `simulator cleanup` outside IOS-018's scratch-home rule, `xcrun simctl shutdown all`, `adb emu kill` on a device you did not create, `pkill`/`killall`, kill by pattern, a kill of a process you did not start (a process a row started, and that process's runner child, count as started by the row), or `git stash`. A row that can only be produced by breaking one of these is `blocked Global Constraint`.
- Default-device rows (B3-L08.1, B3-L08.2, N3-12, N3-13, MCP-031, B2-K37.2, CLI-153): the default simulator name resolves to the owner's `iPhone 18 Pro`, which round 2's MCP build booted. Before each such row: read the default from the MCP `tools/list` schema or `grantiva doctor`, confirm with `findings/round3-smoke.md` that the smoke's no-simulator MCP build returned `isError` and booted nothing (if the smoke booted anything, every such row is `blocked smoke booted the default` and the controller is told at once), and record `xcrun simctl list devices booted` before and after. If the row boots any simulator the slice did not create, the row is `fail`; do not shut that simulator down; tell the controller at once.
- Android shells begin with: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- Load-sensitive rows (B3-L07, B3-L32, B3-L34, B3-L47, B3-L48 and any row the matrix marks with a load condition): record `uptime` before and after; where a row asks for load ≥ 8, generate it with a process the row starts (for example `yes > /dev/null &`, one per core) and stop it by the pid the row recorded, never by pattern.
- Demo apps: copy `/Users/kyle/Developer/landmarks-demo/{ios,android}` (main 75acc87: coverage flows, the Android `10-seed-many` target, and the round-3 swipe-action label "Remove from favorites" that `02-favorite.yaml` taps) to scratch before building. Flows live in `.maestro/` (stock 01-12, 99-crash) and `.maestro/coverage/`; `grantiva.yml` keeps the stock 12 flows and the five screens. The demo configs name `simulator: qa-ios-1` and `emulator: Pixel_8_API_35`: point them at the slice's own device in the scratch copy before any device command.
- Verification, not fixing: nothing under `Sources/`, `Tests/`, `README.md`, `docs/` of the CLI is edited by a slice. A failing row is recorded as `fail` with evidence; every doubtful or inconsistent behaviour is `fail` too (the campaign has no "minor, leave it" bucket). Verdicts: `pass`, `fail`, `blocked <reason>` (environment or a Global Constraint), `n/a <reason>` (row does not apply on this platform). A slice that believes the matrix's expected text is wrong records `fail (matrix/brief error — triage)` with its reading; it never edits the expected text. Expectation corrections are made only in Task 6, through the corrections file.
- Evidence: every row cites a file under the slice's `findings/evidence/cov3-<slice>/<ROW-ID>/` holding the exact command(s) (a `commands.txt`, with the 1-min host load for Android rows) and the raw output; raw captures are verbatim (no edits); write-ups never name any related or upstream project. A row re-run after a fix round or on a quieter host keeps its original line and adds a `<ID> rerun` line beside it in the results file, with its own evidence directory `<ROW-ID>-rerun/`; the original verdict is never overwritten.
- Results: `findings/cov3-<slice>-results.md`, one line per row (`ID | result | evidence | note`); `both` rows record one line per platform half (`<ID> [ios]`, `<ID> [android]`); iOS 27.0 repeats as `<ID> @27.0`. Side findings that no row covers are added as `EXTRA-nn` (CLI), `IOS3-OBS-nn`, `AND3-OBS-nn` lines and count as fails.
- Worktrees `.worktrees/cov3-<slice>` on branches `cov3/<slice>` off `coverage-campaign`; commit there, never push, no attribution lines. Scratch: `/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/cov3-<slice>/`.

## New behaviours and rulings carried from the round-3 fix wave (each is a matrix row)

Fix-wave PRs: runner #21, #22, #23 (grantiva/main after #23, fill: <SHA>), CLI #200–#203 (main 7d7694d5), #205 (the smoke-addendum CLI fixes) and the .13 bundle PR (main after the .13 bundle PR, fill: <SHA>; it follows the round-3 bundle PR #204); landmarks-demo #3 (75acc87). Rows: `B3-L<nn>` per brief, `N3-nn` per new behaviour.

- Rulings that changed a brief's acceptance (the `B3` rows use the ruling, not the brief's original text):
  - L10 (reversed during execution): `--quiet` suppresses progress and runner narration only; the screen/flow blocks and the `Screens:`/`Flows:` lines are the command's result and print on stdout on a failing `run --quiet` as on a passing one.
  - L36: a stop that reaches a `run --keep-alive` runner during its flows ends it as interrupted (runner exit 130, ready file `interrupted`); a stop after the keep-alive hold is armed releases the hold and exits with the status the run earned. A foreground `runner start` ended by `runner stop` exits 0; ended by `simulator teardown`/`emulator teardown` from any directory it exits 0 with `Runner stopped by teardown (pid N); the session has ended.`, via the stop marker `<pid>.stop.json` written beside the owner file in `/tmp/grantiva-sessions` and removed once read or once both processes are gone. A runner that dies on its own still ends the foreground command with exit 1.
  - L48: `GRANTIVA_DRIVER_START_TIMEOUT` (runner `--driver-start-timeout`) sets the UIAutomator2 start limit (default 30 s); `runner start` waits for the session max(90, 2n+30) seconds; a start that fails is reported at once with the runner's reason.
  - L38-b: kill-free readiness: the CLI records the UIAutomator2 session the device already reports and accepts only a different one; nothing is killed on any serial.
  - L15: unknown tool `Error: Unknown tool: <name>`; missing required argument `Error: Invalid argument: '<name>' is required.`
  - L38-a: option 2, a `starting` state on both platforms.
  - L24: a settle on a dead app fails with `app_crash`; a settle after an intentional `stopApp` passes.
  - L07: element swipes use the held-drag path; the demo flow taps the distinct label.
  - L51 (open, round 4): screen-direction swipes, `start:`/`end:` swipes and `engine: adb` still use `adb shell input swipe`; that is the expected behaviour this round.
  - L52 (open at filing; fixed in #205, see the addendum rulings): only the MCP server reports a `run --keep-alive` runner that has not published its session as starting; `hierarchy`/`runner dump-hierarchy` print the no-session text there, as docs/mcp.md documents.
  - "Maestro" stays as the flow-format name in README, help and docs/android.md (not a lineage mention).
- New behaviours (N3 rows): the session `starting` state (MCP tools, `resources/read`, `.grantiva/session.json` `state`, `runner start` while another is starting: `already_running` with `"port": null` and `Runner already running (pid N, starting)`); device-naming lines in MCP build/run/test/boot results (`Simulator: <name> (<udid>)`, `Device: <name> (<serial>)`); the reuse wording (`Emulator reused: <avd> (<serial>), already running`); trimmed Android recordings (3.000 s by `ffprobe`); numeric hierarchy frames on both platforms; the single usage-error shape (exit 64, `Error:` line, `Usage:` and `See '… --help'` lines) for `record --output` and `--device`/`--emulator`; the teardown stop marker; the `--driver-start-timeout` wait; the missing-bundle warning; the MCP and CLI default-device refusals; the per-home capacity ledger; doctor's default-simulator note.
- Briefs L49–L62 were filed during the fix wave and the round-3 smoke addendum: L49, L50 fixed (runner #22 addendum); L52 and L54–L56, L60 fixed in CLI #205; L57–L59 fixed in runner #23; L51, L53, L61, L62 open for round 4 (their rows grade the documented current behaviour as expected and record the measurement). New briefs start at L63.
- Addendum rulings (the `B3-L52`, `B3-L54`…`B3-L60` rows use them):
  - L52 (now fixed in #205, supersedes the open ruling above): `hierarchy` and `runner dump-hierarchy` report a `run --keep-alive` runner that has not published its session as starting, as the MCP server does.
  - L54/L55/L52 share one session lookup: `simulator teardown`/`emulator teardown` from any cwd stops a foreground `runner start` (exit 0, nothing left in `/tmp/grantiva-sessions`); `runner stop` during a keep-alive run's flows ends it with exit 130.
  - L56: a release after the hold exits the earned 0/1 with the Flows summary (and the `Error:` line on failure), not 130.
  - L57: the L05 wall-time target is withdrawn; acceptance is `launchApp` fails on a dead process no later than 2 s after the FATAL, the Flutter probe is skipped for a native app, and the permission grants are one `pm grant` shell.
  - L58: re-baselined to runner overhead under 300 ms with the plain query first; a unique non-clickable match taps its clickable parent.
  - L59: `doubleTapOn` 5 of 5 via `cmd input motionevent` on Android 12+, with an 80 ms floor.
  - L60: iOS `record --duration N` is N s by ffprobe and AVFoundation; frames past N stay in the file.
  - L53, L61, L62 are open for round 4: the rows grade the documented current behaviour as expected.

## Previously blocked rows: re-run rules

Round 2 left 7 real rows blocked (report §Blocked). Round 3 re-runs the ones that are now feasible, exactly as follows; the rest stay blocked for the same reason unless the environment changed.

- **CLI-083 and B-C21.1:** run only while `xcrun simctl list devices booted` lists no simulator at all. If an owner simulator (for example `iPhone 17 Pro`) is booted, they are `blocked owner simulator booted` again; never shut it down. If only campaign simulators are booted, the iOS slice runs both after its Step 4 teardown (CLI-083 is handed over from the CLI slice, which records `blocked (handed to iOS)`).
- **CLI-153:** after L08/L09, run the Quick Start device-free lines as written in a scratch copy under the default-device guard: `init` warns about a default-named simulator Grantiva did not create; `ci run` may stop at the L08 ownership refusal or at the auth error; nothing boots; no device command is run with the `simulator:` line `init` wrote.
- **IOS-018:** with a scratch home: `GRANTIVA_RUNNER_HOME=<scratch>/ios018-home` for every command of the row, so `simulator cleanup` reads only `<scratch>/ios018-home/simulator-capacity/`. Before `simulator cleanup`, that ledger must list only the row's own `cov3-ios-3` (shut down) and `cov3-ios-4` (in an active session under that home); otherwise `blocked`. Checksums of `~/.grantiva-qa/runner/simulator-capacity/created.json` and `~/.grantiva/simulator-capacity/created.json` (read only) are equal before and after.
- **Still blocked unless the environment changed:** AND-002 (1 GB+ system images), AND-012 (`teardown --all`), AND-088 (credentials), B-I06.2 (`/wda/keys` not observable), N-08 (root).

## Review Focus

1. Every matrix row that passed in round 2 still passes on this binary, and every `B2-*` row (now a regression row) still holds. Tasks 3-5.
2. Every round-3 brief's acceptance criteria hold on the platform(s) they name (`B3-L*` rows, as the rulings changed them), including L49/L50 and the addendum briefs L52, L54-L60, and the open L51/L53/L61/L62 rows match the documented current behaviour. Tasks 3-5.
3. Cross-platform consistency: for each command that runs on both platforms, the text and `--json` shapes differ only where the platform demands (device naming, keys documented in docs/android.md); `runner start/stop --json` and `.grantiva/session.json` share one key set; frames are numbers on both. Tasks 4-5.
4. Every Maestro-format flow command the README lists as supported is exercised in at least one real flow per platform and behaves per the README; a crashed app never passes any step kind. Tasks 4-5.
5. The MCP server: every tool in docs/mcp.md exercised against a live session on each platform, plus the no-session, starting and no-config states, and the default-device refusal. Tasks 4-5 (MCP rows), Task 3 (device-free MCP rows).

---

### Task 0: Test home, worktrees, help corpus

Run by the orchestrating session. Fix-wave Task 9 built the release binary from main dc965716, installed it with its bundle in `~/.grantiva-qa/bin/`, upgraded `~/.grantiva-qa/runner` to `1.1.28-grantiva.13+android-drivers-2`, ran the round-3 smoke (`findings/round3-smoke.md`) and regenerated `findings/help/`.

- [ ] **Step 1:** Verify: `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner ~/.grantiva-qa/bin/grantiva runner install | tail -2` (expect already installed, `1.1.28-grantiva.13`); `ls ~/.grantiva-qa/runner/cache/wda-builds | grep -c -- '-r1'` (expect 4; `-r2` if task-8-report says the caches were rebuilt); `~/.grantiva-qa/bin/grantiva --version` (2.1.0); `findings/round3-smoke.md` records the no-simulator MCP build as `isError` with nothing booted.
- [ ] **Step 2:** `cd /Users/kyle/Developer/grantiva-cli && for s in cli ios android; do git worktree add -q .worktrees/cov3-$s -b cov3/$s coverage-campaign; mkdir -p .worktrees/cov3-$s/findings/evidence/cov3-$s; done`.

---

### Task 1: Build the round-3 feature matrix

Done at dispatch (this plan's branch `cov3/plan`): `docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md`.

**Interfaces:**
- Produces: the round-3 matrix with the same row format (`| ID | command/tool | inputs | expected (source) | platform | slice | flow | result |`) and the same stable IDs as round 2, result column empty; the 24 `(corrected round 3)` texts kept; the 127 `B2-*` rows kept as regression rows; new `B3-L<nn>[.k]` rows (one or more per brief L05–L52 and K111, the expected text quoting the measurable part of the acceptance criteria with `(brief Lnn)` as source); new `N3-nn` rows for the behaviours above; the re-run rules written into the inputs of CLI-083, B-C21.1, CLI-153 and IOS-018; a counts line and table at the top and end.

- [x] **Step 1:** Copy the round-2 matrix, clear the result column, keep every row (the round-3 pass is a full pass), keep the corrected expected texts, drop nothing; header updated for round-3 names and versions.
- [x] **Step 2:** Add the `B3` rows from the briefs' Acceptance criteria, using the rulings where they changed the acceptance (L10, L36, L48, L38-b, L15, L24); criteria that ask for a unit or runner test are checked by locating the test in source (CLI main (fill: <SHA>), runner grantiva/main after runner #23 (fill: <SHA>)); no `swift build`/`swift test`/`go test` in a slice.
- [x] **Step 3:** Add the `N3` rows; apply the rulings to the existing rows they contradict (marked `(round 3 ruling: …)`, listed in §Matrix delta).
- [x] **Step 4:** Validate (every row has 8 cells, IDs unique, counts match the header and the Counts table, every brief L05–L62 and K111 has a `B3-` row, every result cell empty):

```bash
cd /Users/kyle/Developer/grantiva-cli/.worktrees/cov3-plan && python3 - <<'EOF'
import re, collections, pathlib
text = pathlib.Path("docs/superpowers/plans/2026-10-13-round3-coverage-matrix.md").read_text()
rows, in_matrix = [], False
for line in text.splitlines():
    if line.startswith("| ID | command/tool |"):
        in_matrix = True; continue
    if not line.startswith("|"):
        in_matrix = False; continue
    if in_matrix and not line.startswith("|---"):
        rows.append([c.strip() for c in re.split(r"(?<!\\)\|", line)[1:-1]])
bad = [r[0] for r in rows if len(r) != 8]
ok = [r for r in rows if len(r) == 8]
dups = [i for i, n in collections.Counter(r[0] for r in rows).items() if n > 1]
filled = [r[0] for r in ok if r[7]]
nosource = [r[0] for r in ok if not r[3] or "(" not in r[3]]
slices = collections.Counter(r[5] for r in ok)
m = re.search(r"\*\*Counts: (\d+) rows\. CLI (\d+), iOS (\d+), Android (\d+), iOS\+Android (\d+)\.\*\*", text)
total_row = re.search(r"\| \*\*all\*\* \| (\d+) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \|", text)
actual = (len(rows), slices["CLI"], slices["iOS"], slices["Android"], slices["iOS+Android"])
table = tuple(int(x) for x in total_row.groups()); table = (table[4],) + table[:4]
briefs = set()
for f in pathlib.Path("docs/superpowers/plans/2026-10-12-coverage-issues-round2").glob("L*.md"):
    parts = f.name.split("-")
    if int(parts[0][1:]) >= 5:
        briefs.add(parts[0] + ("-" + parts[1] if parts[1] in ("a", "b") else ""))
briefs.add("K111")
missing = sorted(b for b in briefs if not any(r[0] == "B3-" + b or r[0].startswith("B3-" + b + ".") for r in rows))
print("rows", len(rows), "bad", bad, "dups", dups, "filled", filled, "nosource", nosource)
print("header", tuple(map(int, m.groups())), "table", table, "actual", actual,
      "match", tuple(map(int, m.groups())) == actual == table)
print("briefs", len(briefs), "missing B3 rows", missing)
EOF
```

Expected output: `bad []`, `dups []`, `filled []`, `nosource []`, `match True`, `missing B3 rows []`. Commit "Add the round 3 coverage matrix".

---

### Task 2: Demo flows

Not needed in round 3 unless a row names a new flow: the coverage flows (round 1), `10-seed-many` (b3f046f) and the swipe-action label (75acc87, demo PR #3) are on landmarks-demo main. Variant flows the rows describe (99-crash variants for B3-L06/L49/L50, the L20 cycle fixtures, the L24 `wait-anim.yaml`, the L33 point-only steps) are written by the slice into its scratch copy under `.maestro/coverage/l<nn>-*.yaml` and saved in the row's evidence. If a row needs a new committed flow, add it by PR as round 1's Task 2 did (worktree `.worktrees/coverage-flows-3`, branch `coverage-flows-3`, devices `cov3-flows-ios`/`cov3-flows-android`, deleted at the end).

---

### Task 3: CLI slice

Agent, worktree `.worktrees/cov3-cli`, `GRANTIVA_SESSION_ID=cov3-cli`, no devices.

- [x] **Step 1:** Run every matrix row with slice `CLI` in ID order; one evidence dir per row; results in `findings/cov3-cli-results.md` (`ID | result | evidence | note`). CLI-083 is handed to iOS (re-run rules).
- [x] **Step 2:** The device-free MCP rows (no session, no config, tools/list, schema, error texts, cancellation) via the stdio script.
- [x] **Step 3:** Help-corpus consistency: every README/docs command example re-run against `findings/help/` (regenerated in fix-wave Task 9; any mismatch is a `fail`).
- [x] **Step 4:** Commit "CLI slice results for the round 3 coverage pass".

---

### Task 4: iOS slice

Agent, worktree `.worktrees/cov3-ios`, `GRANTIVA_SESSION_ID=cov3-ios`, simulators `cov3-ios-26` (26.0) and `cov3-ios-27` (27.0).

- [x] **Step 1:** Run the default-device rows first, before creating any simulator, under the default-device guard (N3-13, B3-L08.1 with B2-K37.2, B3-L08.2, N3-12; MCP-031's no-simulator call is graded by B3-L08.1/N3-13): `xcrun simctl list devices booted` before and after each.
- [x] **Step 2:** Create both simulators; build and install the scratch iOS app on both; `run --no-build` of the stock set on both (12/12 + screens, cache-hit line `sim-ios<rt>-iphone-wda16.12.8-r1` (or `-r2` per Task 0), no first-time build).
- [x] **Step 3:** Every matrix row with slice `iOS` and the iOS half of every `iOS+Android` row (incl. the CLI rows the matrix hands to iOS, the MCP live-session rows, the B/B2/B3 rows for iOS briefs, the N/N2/N3 and X rows), on 26.0; repeat the flow-command rows and the stock set on 27.0 (`<ID> @27.0`); evidence per row.
- [x] **Step 4:** Concurrency row (two simulators, two shells), capacity rows (extra sims `cov3-ios-3/-4`, deleted inside the row), IOS-018 under its scratch-home rule, teardown rows (device homes gone).
- [x] **Step 5:** Teardown both simulators, `xcrun simctl list devices | grep -c cov3-ios` = 0; then CLI-083 and B-C21.1 under the re-run rule; commit "iOS slice results for the round 3 coverage pass".

---

### Task 5: Android slice

Agent, worktree `.worktrees/cov3-android`, `GRANTIVA_SESSION_ID=cov3-android`, AVD `cov3-android`.

- [ ] **Step 1:** `adb devices` empty check (a device you did not create is left alone and noted); `emulator ensure --name cov3-android`; build+install the scratch Android app; stock set 12/12 + screens; `99-crash` fails fast with `app_crash` at `launchApp` or the first step after it (record time from `am_crash` to failure and the wall time).
- [ ] **Step 2:** Every matrix row with slice `Android` and the Android half of every `iOS+Android` row (CLI rows handed to Android, MCP live-session rows, B/B2/B3 rows for Android briefs and R01/R02, N/N2/N3 rows, X rows); load-sensitive rows per the load rule; `emulator` capacity rows with `cov3-android-2` created and deleted inside the row.
- [ ] **Step 3:** Teardown and `avdmanager delete avd -n cov3-android`; `adb devices` empty (apart from devices you did not create), no `cov3-` AVDs; commit "Android slice results for the round 3 coverage pass".

---

### Task 6: Merge, triage, round report

Run by the orchestrating session.

- [ ] **Step 1:** `git merge --no-ff cov3/cli cov3/ios cov3/android` into `coverage-campaign`.
- [ ] **Step 2:** Every `fail` row becomes a brief `docs/superpowers/plans/2026-10-13-coverage-issues-round3/L<nn>-<slug>.md`, numbering from **L63** (L62 is the last round-3 brief; if the parked stop-marker item from the fix-wave ledger is confirmed, it takes the first free number), same sections and severity vocabulary as the L briefs; cite the matrix row, the brief it regresses or reopens, and the fix-wave PR. A fail on a `B3-L51` or `B3-L52` row reopens that brief for round 4 instead of a new one. `blocked` rows are listed in the report with the reason. Rows the slice marks `fail (matrix/brief error — triage)` go to `00-expectation-corrections-round3.md`; the matrix rows they correct gain `(corrected round 4)`.
- [ ] **Step 3:** `docs/superpowers/plans/2026-10-13-round3-coverage-report.md`: binary and runner versions, matrix size and results per slice (pass / fail / blocked / n-a, `rerun` lines counted separately), Review Focus 1-5 verdicts, the per-brief verification table (every `B3` row's verdict, and every `B2` regression), the re-run outcome of the previously blocked rows, the brief list, host state after cleanup, and the exit-criterion statement: `ROUND 3: CLEAN` only if zero `fail` rows, otherwise `ROUND 3: <n> findings — round 4 fix wave required` with the brief IDs.
- [ ] **Step 4:** Commit and push `coverage-campaign`; update `docs/superpowers/plans/2026-10-12-campaign-handoff.md` and `findings/ledgers/`. If CLEAN: the campaign's exit criterion is met; present the final summary to the owner (release stays their call). Otherwise write `docs/superpowers/plans/<date>-round4-fix-wave.md` from the new briefs plus L51/L52 (writing-plans) and execute it.

---

## Matrix delta

Round 2 → round 3 (`2026-10-12-round2-coverage-matrix.md` → `2026-10-13-round3-coverage-matrix.md`): every round-2 row kept with its ID, results cleared.

**Rows added: 86** (1084 → 1170; CLI 365 → 384, iOS 305 → 319, Android 277 → 308, iOS+Android 137 → 159).

| family | rows | CLI | iOS | Android | iOS+Android | what |
|---|---|---|---|---|---|---|
| `B3-L05`…`B3-L62`, `B3-K111` | 70 | 15 | 11 | 29 | 15 | one per brief L05–L62 (incl. L26-a/b, L38-a/b, L42-a/b, the fixed L49/L50 and the open L51, L53, L61, L62 and the fixed-in-#205 L52) and K111; split by slice or criterion: L08 (.1 MCP, .2 CLI), L14 (.1 device-free, .2 live build), L15 (.1 device-free, .2 live session), L36 (.1 foreground stop, .2 keep-alive ruling), L48 (.1 limit and wait, .2 fast failure); L54, L55, L56 (.1 iOS, .2 Android). Added after the briefs L53–L62: `B3-L53`, `B3-L54.1`, `B3-L54.2`, `B3-L55.1`, `B3-L55.2`, `B3-L56.1`, `B3-L56.2`, `B3-L57`, `B3-L58`, `B3-L59`, `B3-L60`, `B3-L61`, `B3-L62` (13 rows: CLI 1, iOS 4, Android 8); `B3-L52` now expects the fixed behaviour (round 3 ruling: fixed in #205) |
| `N3-01`…`N3-16` | 16 | 4 | 3 | 2 | 7 | starting state (MCP tools, `resources/read`, `runner start` while starting), device-naming lines, reuse wording, trimmed 3 s recordings, numeric frames on both platforms, usage-error shape, teardown stop marker, `--driver-start-timeout` on `run`, missing-bundle warning, MCP default-device refusals (other tools; `grantiva_build` with nothing booted), per-home capacity ledger, doctor's default note, docs/help for the round-3 additions |

**Rows whose expected text changed** (marked `(round 3 ruling: …)` in the matrix; every other round-2 expected text is unchanged, including the 24 `(corrected round 3)` ones):

| row | change | ruling |
|---|---|---|
| MCP-031 | inputs name `simulator: "cov3-ios-26"`; expected adds the `Simulator: <name> (<udid>)` line; the no-simulator half moves to B3-L08.1/N3-13 | L08 (a user-created default is refused) |
| B2-K37.2 | the default (owner's `iPhone 18 Pro`, not created by Grantiva) is refused with the docs/mcp.md text and nothing boots; guarded by the default-device rule | L08 |
| B2-L02 | 99-crash fails at `launchApp` or the first step after it (was: at `assertVisible "Landmarks"`) | fix-wave Task 1 (cold `launchApp` waits for the first frame; AND-107 correction) |
| B2-L05 | same wording for the 99-crash half | fix-wave Task 1 |
| D2-19 | `--quiet` silences the runner's own summary on stderr; grantiva's stdout blocks and `Screens:`/`Flows:` lines still print, passing or failing | L10 reversal |
| B3-L52 | hierarchy/dump-hierarchy say starting during a keep-alive start (was: documented no-session text, open) | L52 fixed in CLI #205 |
| CLI-153 | `ci run` may stop at the L08 ownership refusal instead of the auth error; `init` warns about a non-Grantiva default; nothing boots | L08/L09 |

**Inputs changed (re-run rules, expected unchanged):** CLI-083, B-C21.1 (run only with no simulator booted; owner simulator booted → blocked again; CLI-083 handed to iOS), IOS-018 (scratch `GRANTIVA_RUNNER_HOME`, ledger lists only `cov3-ios-3`/`-4`), CLI-153 (above).

**Reading rules (header, no row text changed):** device names `cov-*`/`cov2-*` read as `cov3-*` (`cov2-ios-1` → `cov3-ios-26`, `cov2-ios-2` → `cov3-ios-27`); runner literals `1.1.28-grantiva.11` (CLI-085, CLI-161, N2-02 and others) read as the bundled `1.1.28-grantiva.13` (CLI-085: "the literal follows the bundled runner"); `findings/help/` is the corpus regenerated in fix-wave Task 9; demo main is 75acc87.
