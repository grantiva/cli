# CLI slice results: round 1 coverage pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (runner 1.1.28-grantiva.9), `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`,
`GRANTIVA_SESSION_ID=cov-cli`, `GRANTIVA_API_KEY` unset. No devices: device steps use UDID
`00000000-0000-0000-0000-0000000000C1` / serial `emulator-9999`. Evidence under `findings/evidence/cov-cli/<ID>/`
(`commands.txt` holds the exact commands, cwd and exit codes; `*.out`/`*.err` the raw stdout/stderr).

| ID | result | evidence | note |
|---|---|---|---|
| CLI-001 | pass | findings/evidence/cov-cli/CLI-001/ | exit 0; --version 2.1.0; overview and all 14 subcommands as expected; byte-identical to help/grantiva.txt |
| CLI-002 | pass | findings/evidence/cov-cli/CLI-002/ | help run / runner start / console flags byte-identical to --help, exit 0 |
| CLI-003 | pass | findings/evidence/cov-cli/CLI-003/regen.out | 172/172 pages exit 0 with OVERVIEW, USAGE, OPTIONS; all byte-identical to findings/help |
| CLI-004 | pass | findings/evidence/cov-cli/CLI-004/ | help identical to corpus; all README/android.md flags present; removed flags absent; --wait-for-idle-timeout exit 64 Unknown option |
| CLI-005 | pass | findings/evidence/cov-cli/CLI-005/ | install adds --app-file, --no-build, --derived-data-path(moved), --no-launch; build marked (default); bare build behaves as build build |
| CLI-006 | pass | findings/evidence/cov-cli/CLI-006/ | compare adds --capture (runs full lifecycle); approve takes <screen-names> and --platform plus the shared --json/--verbose/--quiet, no device options |
| CLI-007 | pass | findings/evidence/cov-cli/CLI-007/ | 10 pages exit 0; ensure --boot/--no-boot (default: --boot); teardown --serial/--all/--force; delete --name/--force |
| CLI-008 | fail | findings/evidence/cov-cli/CLI-008/runner_dump-hierarchy.out | row items present (7 pages exit 0; -p/--port, -f/--format tree\|json\|xml default tree, --udid; record --duration required), but `runner dump-hierarchy -p, --port` reads "WDA port (auto-detected from active session if omitted)" although the command also serves Android (UIAutomator2) sessions per docs/dump-hierarchy.md:57 and its own --udid "adb serial" text: iOS-only wording on a both-platform flag |
| CLI-009 | pass | findings/evidence/cov-cli/CLI-009/ | 17 groups listed in order; flags alias featureflags; featureflags --help byte-identical to flags --help |
| CLI-010 | pass | findings/evidence/cov-cli/CLI-010/ | both exit 64, usage error on stderr, stdout empty |
| CLI-123 | fail | findings/evidence/cov-cli/CLI-123/ | expected the abstract to name the Android driver as README:333 does ("Start the runner with WDA (UIAutomator2 on Android) and keep it alive..."); actual `runner start --help` OVERVIEW "Start the runner with WDA and keep it alive for interactive use." (N07 unfixed) |
| CLI-124 | pass | findings/evidence/cov-cli/CLI-124/ | DISCUSSION: starts without session or config; lists the session-needing device tools; --project-dir and --platform present |
| CLI-125 | fail | findings/evidence/cov-cli/CLI-125/help.out | row items present (/tmp/grantiva-sessions, newest session, --udid UDID or adb serial, --timeout default 60, --format xml/json, --json = --format json), but `--timeout` reads "Seconds to wait for GrantivaAgent's page-source response" while the same page says Android reads "from the UIAutomator2 server": iOS-only wording on a both-platform flag |
| CLI-011 | fail | findings/evidence/cov-cli/CLI-011/jq_on_failing_doctor.out | stdout is a valid JSON array with `status`, no narration; but the README:380 filter `select(.status == "fail")` can never match: doctor's status values are ok, warning, error (DoctorCheck.swift:11-13). With DEVELOPER_DIR=/nonexistent in an iOS project (Xcode and Xcode Version `"status": "error"`, exit 1) the filter prints nothing. Expected the documented filter to select failing checks |
| CLI-012 | pass | findings/evidence/cov-cli/CLI-012/ | stdout valid JSON array, stderr empty |
| CLI-013 | pass | findings/evidence/cov-cli/CLI-013/ | stdout valid JSON identical to the quiet run; stderr has [debug] timestamped, labelled lines for all 7 subprocesses with exit status |
| CLI-014 | pass | findings/evidence/cov-cli/CLI-014/ | redirected stdout has 0 ESC lines; on a pty (script -q) 22 coloured lines, with NO_COLOR=1 0 |
| CLI-015 | pass | findings/evidence/cov-cli/CLI-015/ | plain, --quiet, --verbose: stdout valid identical JSON; [debug] lines only on stderr under --verbose |
| CLI-016 | pass | findings/evidence/cov-cli/CLI-016/ | plain, --quiet, --verbose: stdout valid identical JSON; [debug] lines only on stderr under --verbose |
| CLI-017 | pass | findings/evidence/cov-cli/CLI-017/ | text grantiva-runner 1.1.28-grantiva.9; --json {"version": ...} valid |
| CLI-019 | fail | findings/evidence/cov-cli/CLI-019/ | teardown --json (exit 64), diff compare --json (exit 1) and run --json (exit 1, stdout {"allPassed": false, "error": ..., "screens": []}) behave as expected; doctor --json with DEVELOPER_DIR=/nonexistent in an iOS project exits 1 with the full check array on stdout and nothing on stderr (no `Error:` line). Expected `Error:` on stderr and stdout empty; actual stdout JSON, stderr empty (in an empty dir the same failure is only a warning and exits 0, see CLI-026) |
| CLI-020 | pass | findings/evidence/cov-cli/CLI-020/ | init: narration 'Created grantiva.yml' gone, Warning kept, same file; run: Resolved/Preparing/Booting narration gone, Error kept; stdout empty in both modes |
| CLI-021 | pass | findings/evidence/cov-cli/CLI-021/ | run: [debug] timestamped/labelled subprocess lines added on stderr; doctor stdout byte-identical with and without --verbose, 14 debug lines on stderr |
| CLI-126 | pass | findings/evidence/cov-cli/CLI-126/ | install --json {path,status:installed,version}; stop --json {status:not_running}; both valid JSON, exit 0 |
| CLI-023 | pass | findings/evidence/cov-cli/CLI-023/ | doctor shows iOS checks only and grantiva.yml advice; init writes grantiva.yml with scheme Landmarks |
| CLI-024 | pass | findings/evidence/cov-cli/CLI-024/ | doctor runs Android checks and grantiva-android.yml advice (JDK fails only because JAVA_HOME is unset in this shell); init writes grantiva-android.yml |
| CLI-025 | fail | findings/evidence/cov-cli/CLI-025/ | run: exact message, exit 1 (ok). doctor: expected to report the ambiguity and exit non-zero (brief C12: or demote the second platform to advice); actual exit 0, the ambiguity is only an optional `● Platform  Found both an Xcode project and Gradle settings` warning while both the iOS and the Android checks are listed under Required |
| CLI-026 | fail | findings/evidence/cov-cli/CLI-026/ | exit code ok: empty dir with DEVELOPER_DIR=/nonexistent and no JDK exits 0 ("6 passed · 9 optional"), missing project advisory. Inconsistent presentation: the advisory toolchain checks (● Xcode, ● JDK) are printed under the "Required" heading (JSON `"section": "Required"`, `"status": "warning"`), so the heading contradicts the summary that counts them optional |
| CLI-027 | pass | findings/evidence/cov-cli/CLI-027/ | no grantiva.yml: run resolves screens=4 (the 4 takeScreenshot points of the two .maestro flows) and stops at device resolution; diff capture likewise stops only at 'Simulator not found' |
| CLI-028 | fail | findings/evidence/cov-cli/CLI-028/ | with the row input (no grantiva.yml, empty .maestro/) expected run to say `No grantiva.yml here. Create one with grantiva init.`; actual run and diff capture both `Error: Invalid argument: No flow files found in <dir>/.maestro` (exit 1), which never names the missing config. Also inconsistent: without --no-build and no .maestro, run says `No scheme specified ...` instead; with --no-build run says `No grantiva.yml here. Create one with grantiva init.` while diff capture says `grantiva.yml not found at <dir>/grantiva.yml. Create one with grantiva init.` for the same condition |
| CLI-029 | pass | findings/evidence/cov-cli/CLI-029/ | Maestro-format grantiva.yml parsed into 2 screens (run resolves screens=2); diff capture fails only at Simulator not found |
| CLI-030 | pass | findings/evidence/cov-cli/CLI-030/ | exact message, exit 1 |
| CLI-031 | pass | findings/evidence/cov-cli/CLI-031/ | --platform android selects grantiva-android.yml (module=app variant=freeDebug) for run and doctor; GRANTIVA_PLATFORM=ios selects grantiva.yml for both |
| CLI-032 | pass | findings/evidence/cov-cli/CLI-032/ | --platform ios beats GRANTIVA_PLATFORM=android |
| CLI-033 | pass | findings/evidence/cov-cli/CLI-033/ | doctor, run, init each exit 1 with the message; dir stays empty (no file written) |
| CLI-034 | pass | findings/evidence/cov-cli/CLI-034/ | exact message, exit 1 |
| CLI-035 | pass | findings/evidence/cov-cli/CLI-035/ | exit 64, names ios and android |
| CLI-127 | pass | findings/evidence/cov-cli/CLI-127/ | " Android " -> Android checks; "" in a grantiva.yml dir -> iOS (as unset) |
| CLI-128 | pass | findings/evidence/cov-cli/CLI-128/ | exit 64 naming ios and android; stdout empty |
| CLI-036 | pass | findings/evidence/cov-cli/CLI-036/ | names grantiva.yml and 6:1 (flow sequence opened at line 5 column 11), exit 1 |
| CLI-037 | pass | findings/evidence/cov-cli/CLI-037/ | names grantiva-android.yml and 5:4, exit 1 |
| CLI-038 | pass | findings/evidence/cov-cli/CLI-038/ | empty and comments-only: exact message exit 1 (with --no-build, and in an iOS project without it, before any build) |
| CLI-039 | pass | findings/evidence/cov-cli/CLI-039/ | run warns with file:line and suggestion for both keys; doctor shows them as a Project warning (text and JSON) |
| CLI-040 | pass | findings/evidence/cov-cli/CLI-040/ | Error: grantiva.yml declares platform: android but it is the iOS config file, exit 1 |
| CLI-041 | pass | findings/evidence/cov-cli/CLI-041/ | exact message, exit 1, no build |
| CLI-042 | pass | findings/evidence/cov-cli/CLI-042/ | exact message, exit 1, no build |
| CLI-043 | pass | findings/evidence/cov-cli/CLI-043/ | --logs-predicate rejected on Android, --logs-tag on iOS, by name, before any build |
| CLI-044 | fail | findings/evidence/cov-cli/CLI-044/ | row expectations hold (exit 1 `No screens or flows configured in grantiva.yml` before any boot, no out/report.json, out.ready `"status": "failed"`), but out.ready carries `"reportDir": "out"` for a directory that was never created, and has no `error` field although the failure reason is known (a usage error such as --timeout 5 records one, README:85): doubtful ready-file content |
| CLI-045 | pass | findings/evidence/cov-cli/CLI-045/ | exact message, exit 1, before device work (emulator-9999 used for emulator-5554) |
| CLI-046 | pass | findings/evidence/cov-cli/CLI-046/ | every step form parses (screens=2); diff capture and run fail only at Simulator not found |
| CLI-047 | pass | findings/evidence/cov-cli/CLI-047/ | exact message before boot or build, exit 1 |
