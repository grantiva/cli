# CLI slice results: round 2 coverage pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (main c65fc17, bundled runner `grantiva-runner 1.1.28-grantiva.11`, installed
stamp `1.1.28-grantiva.11+android-drivers-2`), `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`, `GRANTIVA_SESSION_ID=cov2-cli`,
`GRANTIVA_API_KEY` unset (preamble: `findings/evidence/cov2-cli/inputs/env.sh`; helpers `inputs/lib.sh`, MCP clients
`inputs/send.sh` and `inputs/client.py`). No devices: device steps use the fake UDID `00000000-0000-0000-0000-0000000000C1`,
serial `emulator-9999` and names `cov-missing`; project copies of landmarks-demo (b3f046f) have their `simulator:`/`emulator:`
lines pointed at `cov-missing` so no command can reach an owner device (`qa-ios-1`, `Pixel_8_API_35`).
Evidence under `findings/evidence/cov2-cli/<ID>/` (`commands.txt`: cwd, command, exit code and elapsed time; `<label>.out` /
`<label>.err` raw stdout/stderr). README, docs and source checks read the c65fc17 tree (the binary's commit; the worktree's own
README/docs are older), exported read-only to scratch. No `swift build`/`swift test` was run: unit-test criteria are checked by
reading `Tests/` at c65fc17 (`git grep`), which proves a test exists, not that it passes.
`fail (matrix/brief error — triage)` marks rows whose expected text is stale against a later ruling or fix; the observed behaviour
is in the note.


| ID | result | evidence | note |
|---|---|---|---|
| CLI-001 | pass | findings/evidence/cov2-cli/CLI-001/ | exit 0; --version 2.1.0; OVERVIEW as expected; all 14 subcommands listed; byte-identical to findings/help/grantiva.txt |
| CLI-002 | pass | findings/evidence/cov2-cli/CLI-002/ | help run / runner start / console flags byte-identical to --help, exit 0 |
| CLI-003 | fail (matrix/brief error — triage) | findings/evidence/cov2-cli/CLI-003/regen.out | 172/172 pages exit 0 with OVERVIEW, USAGE, OPTIONS; 170 byte-identical; runner_stop and simulator_teardown differ from findings/help (corpus 7593fab predates L04 #198 in c65fc17, which added the helper-reaping / leftoverProcesses sentences; diffs in runner_stop.diff, simulator_teardown.diff). Corpus stale, not a binary defect |
| CLI-004 | pass | findings/evidence/cov2-cli/CLI-004/ | help byte-identical to run.txt; every run flag README Agent-Native and docs/android.md Flags name present; no --auto-accept-alerts/--no-auto-accept-alerts/--wait-for-idle-timeout; --wait-for-idle-timeout 5 exit 64 Unknown option |
| CLI-005 | pass | findings/evidence/cov2-cli/CLI-005/ | pages identical to corpus; build install adds exactly --app-file, --no-build, --no-launch over build build; build marked (default); bare build behaves as build build (same error, exit 1, empty dir) |
| CLI-006 | pass | findings/evidence/cov2-cli/CLI-006/ | pages identical to corpus; compare adds --capture (runs full lifecycle); approve takes [<screen-names> ...] and --platform plus the shared --json/--verbose/--quiet |
| CLI-007 | pass | findings/evidence/cov2-cli/CLI-007/ | all pages exit 0; ensure --boot/--no-boot (default: --boot); emulator teardown --serial/--all/--force; emulator delete --name/--force. simulator_teardown differs from the stale corpus only by the L04 sentences (see CLI-003). emulator has no cleanup subcommand (emulator cleanup --help prints the group page, exit 0; without --help exit 64), consistent with the corpus, which has no emulator_cleanup page |
| CLI-008 | pass | findings/evidence/cov2-cli/CLI-008/ | 7 pages exit 0; dump-hierarchy -p/--port (now names WDA on iOS and UIAutomator2 on Android), -f/--format tree\|json\|xml default tree, --udid; record --duration required (unbracketed in USAGE). runner_stop differs from the stale corpus only by the L04 sentences (see CLI-003) |
| CLI-009 | pass | findings/evidence/cov2-cli/CLI-009/ | 17 groups listed in order (flags shown as 'flags, featureflags'); console featureflags --help byte-identical to console flags --help; page identical to corpus |
| CLI-010 | pass | findings/evidence/cov2-cli/CLI-010/ | both exit 64, usage error on stderr, stdout empty |
| CLI-123 | pass | findings/evidence/cov2-cli/CLI-123/ | runner start OVERVIEW and runner --help abstract read 'Start the runner with WDA (UIAutomator2 on Android) and keep it alive for interactive use.', identical to README Commands line (README:357 at c65fc17) |
| CLI-124 | pass | findings/evidence/cov2-cli/CLI-124/ | DISCUSSION: starts without a runner session or config; lists the session-needing device tools; --project-dir and --platform present; matches docs/mcp.md Runner session section |
| CLI-125 | pass | findings/evidence/cov2-cli/CLI-125/help.out | discussion names /tmp/grantiva-sessions and UDID or adb serial; --udid default newest keep-alive session; --timeout default 60 and now names both drivers; --format xml/json; --json same as --format json |
| CLI-011 | pass | findings/evidence/cov2-cli/CLI-011/ | stdout is a valid JSON array, every check has status, no narration on stdout; README filter (README:439 at c65fc17) now reads select(.status == "error") (K62) and selects the two failing Xcode checks with DEVELOPER_DIR=/nonexistent; the row's literal 'fail' filter prints nothing by design (statuses are ok/warning/error, see D2-16) |
| CLI-012 | pass | findings/evidence/cov2-cli/CLI-012/ | stdout valid JSON array (8 checks), stderr empty |
| CLI-013 | pass | findings/evidence/cov2-cli/CLI-013/verbose.err | stdout valid JSON (8 checks); stderr has [debug] timestamped, labelled lines for each of the 3 subprocesses with exit status |
| CLI-014 | pass | findings/evidence/cov2-cli/CLI-014/ | redirected stdout (out.txt) has 0 ESC bytes; on a TTY (script -q) 13 lines carry ANSI escapes, with NO_COLOR=1 none |
| CLI-015 | pass | findings/evidence/cov2-cli/CLI-015/ | stdout valid JSON in plain, --quiet and --verbose (exit 0); diagnostics ([debug] lines) only on stderr in --verbose |
| CLI-016 | pass | findings/evidence/cov2-cli/CLI-016/ | stdout valid JSON in all three (exit 0); [debug] lines only on stderr in --verbose |
| CLI-017 | pass | findings/evidence/cov2-cli/CLI-017/ | prints 'grantiva-runner 1.1.28-grantiva.11' (the bundled runner); --json {"version": "1.1.28-grantiva.11"} valid JSON |
| CLI-019 | pass | findings/evidence/cov2-cli/CLI-019/ | teardown --json: exit 64, Error on stderr, stdout empty; diff compare --json: exit 1, Error on stderr, stdout empty; run --json: exit 1, stdout {allPassed:false, error, screens:[]}, Error on stderr; doctor --json in an iOS project with DEVELOPER_DIR=/nonexistent: exit 1, full 8-check array on stdout, stderr empty (in an empty dir the toolchain checks are Advisory warnings and doctor exits 0, per K35) |
| CLI-020 | pass | findings/evidence/cov2-cli/CLI-020/ | init: 'Created grantiva.yml' narration gone under --quiet, both Warning lines kept, identical file; run: Resolved/Preparing/Runner ready/Booting narration gone, Error kept; stdout empty in all modes |
| CLI-021 | pass | findings/evidence/cov2-cli/CLI-021/ | run --verbose adds [debug] timestamped, labelled subprocess lines on stderr, stdout empty both ways; doctor stdout byte-identical with and without --verbose, 6 [debug] lines on stderr only with it |
| CLI-126 | pass | findings/evidence/cov2-cli/CLI-126/ | runner install --json {extracted:false, path, status:installed, version}; runner stop --json {status:not_running}; both valid JSON, exit 0 |
| CLI-023 | pass | findings/evidence/cov2-cli/CLI-023/ | doctor runs the Xcode checks under Required (no Android checks); init writes grantiva.yml (iOS) |
| CLI-024 | pass | findings/evidence/cov2-cli/CLI-024/ | doctor runs Android SDK/adb/Emulator/JDK checks under Required; init writes grantiva-android.yml |
| CLI-025 | fail (matrix/brief error — triage) | findings/evidence/cov2-cli/CLI-025/ | run: exact message, exit 1. doctor reports '● Platform  Found both an Xcode project and Gradle settings' but exits 0: it takes brief C12's alternative (both platforms as advice, now under an 'Advisory' heading after K35; exit 0 even with failing Xcode/JDK). The row's 'exits non-zero' contradicts the alternative B-C12.1 allows; needs a ruling |
| CLI-026 | pass | findings/evidence/cov2-cli/CLI-026/ | empty dir, DEVELOPER_DIR=/nonexistent, no JAVA_HOME: Xcode and Android toolchain checks all under 'Advisory' with fix lines, missing config files advisory, exit 0 |
| CLI-027 | pass | findings/evidence/cov2-cli/CLI-027/ | no grantiva.yml: run resolves screens=4 from the two .maestro flows' takeScreenshot points and stops at device resolution (fake UDID); diff capture likewise stops only at 'Simulator not found' |
| CLI-028 | pass | findings/evidence/cov2-cli/CLI-028/ | no config + empty .maestro/: run, run --no-build, diff capture, diff capture --no-build (bare dir and Xcode dir) all print the same 'Error: Invalid argument: No flow files found in <dir>/.maestro', exit 1 |
| CLI-029 | pass | findings/evidence/cov2-cli/CLI-029/ | Maestro-format grantiva.yml (README example) parsed: run resolves screens=2; diff capture fails only at 'Simulator not found' (fake UDID) |
| CLI-030 | pass | findings/evidence/cov2-cli/CLI-030/ | exact message, exit 1 |
| CLI-031 | pass | findings/evidence/cov2-cli/CLI-031/ | both configs: --platform android selects grantiva-android.yml (run Resolved module=app variant=freeDebug; doctor runs Android checks, grantiva-android.yml Found); GRANTIVA_PLATFORM=ios selects grantiva.yml (run Resolved scheme=Landmarks (UI Testing); doctor Xcode checks, grantiva.yml Found). Configs were copied without flows: so run reaches resolution (fake device) |
| CLI-032 | pass | findings/evidence/cov2-cli/CLI-032/ | GRANTIVA_PLATFORM=android doctor --platform ios runs the iOS checks and grantiva.yml: the flag wins |
| CLI-033 | pass | findings/evidence/cov2-cli/CLI-033/ | doctor, run, init each exit 1 with 'GRANTIVA_PLATFORM is "windows"; expected ios or android.'; dir stays empty |
| CLI-034 | pass | findings/evidence/cov2-cli/CLI-034/ | exact message, exit 1 |
| CLI-035 | pass | findings/evidence/cov2-cli/CLI-035/ | exit 64, names ios and android |
| CLI-127 | pass | findings/evidence/cov2-cli/CLI-127/ | ' Android ' -> Android checks (trimmed, lower-cased); '' in an Xcode-only dir -> iOS checks (treated as unset) |
| CLI-128 | pass | findings/evidence/cov2-cli/CLI-128/ | exit 64 naming ios and android; stdout empty (no JSON-RPC) |
| CLI-036 | pass | findings/evidence/cov2-cli/CLI-036/ | error names grantiva.yml and 6:9 (flow sequence opened at line 5 column 11), exit 1 |
| CLI-037 | pass | findings/evidence/cov2-cli/CLI-037/ | error names grantiva-android.yml and 6:1, exit 1 |
| CLI-038 | fail (matrix/brief error — triage) | findings/evidence/cov2-cli/CLI-038/ | empty and comments-only grantiva.yml: exit 1, before any build (with --no-build, and in an iOS project with --scheme), but the text is 'Error: No screens or flows configured in grantiva.yml' without the row's 'Invalid argument:' label (RunCommand.nothingToRunMessage, shared with the K52 missing-config sentence, is deliberately unlabelled at c65fc17). Without --scheme the two-scheme demo gets the scheme error first (K52 allows it) |
| CLI-039 | pass | findings/evidence/cov2-cli/CLI-039/ | run prints 'Warning: grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)' and the line-4 'screen' warning on stderr before its error; doctor shows both as a Project warning (text and JSON) |
| CLI-040 | pass | findings/evidence/cov2-cli/CLI-040/ | 'grantiva.yml declares `platform: android` but it is the iOS config file.', exit 1 |
| CLI-041 | pass | findings/evidence/cov2-cli/CLI-041/ | exact long-form message, exit 1, before any build |
| CLI-042 | pass | findings/evidence/cov2-cli/CLI-042/ | exact long-form message, exit 1 |
| CLI-043 | pass | findings/evidence/cov2-cli/CLI-043/ | --logs-tag on iOS and --logs-predicate on Android each rejected by name, exit 1, before any build |
| CLI-044 | pass | findings/evidence/cov2-cli/CLI-044/ | flows: [] with no screens: exit 1 'No screens or flows configured in grantiva.yml' before any boot; no out/ directory (no report.json); out.ready {status: failed, error, flows: []} |
| CLI-045 | pass | findings/evidence/cov2-cli/CLI-045/ | '--device and --emulator are mutually exclusive; pass one.', exit 1, before device work (fake serial/AVD names used) |
| CLI-046 | pass | findings/evidence/cov2-cli/CLI-046/ | every documented step parses (launch, tap, tap {text, exact}, swipe up/down/left/right/UP, type, wait, assert_visible, both assert_not_visible forms, run_flow): run resolves screens=2 and both commands fail only at 'Simulator not found'. (First fixture put launch inside a list, which README does not document; recorded in commands.txt) |
| CLI-047 | pass | findings/evidence/cov2-cli/CLI-047/ | exact message before boot or build, exit 1 |
| CLI-048 | blocked needs a device | findings/evidence/cov2-cli/CLI-048/ | relative run_flow and a missing run_flow path both stop at 'Simulator not found' (fake UDID): run_flow references are not resolved before device resolution, so relative resolution and the missing-path error are only observable with a device; iOS slice should take it |
| CLI-049 | blocked needs a device | findings/evidence/cov2-cli/CLI-049/ | a->b->a cycle: no hang (0.26 s), stops at 'Simulator not found' before any cycle check; the cycle error is only observable with a device; iOS slice should take it |
| CLI-050 | pass | findings/evidence/cov2-cli/CLI-050/ | four exact messages, exit 1, before device work |
| CLI-051 | pass | findings/evidence/cov2-cli/CLI-051/ | rejected at startup: '--ready-file adir is a directory, not a file.', exit 1; directory untouched |
| CLI-052 | pass | findings/evidence/cov2-cli/CLI-052/ | stale passed file replaced by status failed with a fresh finishedAt and the error, exit 1 |
| CLI-053 | pass | findings/evidence/cov2-cli/CLI-053/ | x.ready written with status failed (and error), exit 1 |
| CLI-054 | pass | findings/evidence/cov2-cli/CLI-054/ | '--ready-file ro/x.ready is not writable.', exit 1, before project work (0.02 s) |
| CLI-055 | pass | findings/evidence/cov2-cli/CLI-055/ | exit 64; error line 'Please provide one of 'failure', 'trailing' or 'full'.' |
| CLI-056 | pass | findings/evidence/cov2-cli/CLI-056/ | --timeout abc: exit 64 invalid value; --timeout -1: exit 64 '--timeout must be at least 30 seconds.' (K41 fixed the round-1 'Missing value') |
| CLI-129 | pass | findings/evidence/cov2-cli/CLI-129/ | exit 64 '--timeout must be at least 30 seconds.'; r.ready status failed with that error |
| CLI-130 | pass | findings/evidence/cov2-cli/CLI-130/ | still exit 64 with the same message under --keep-alive |
| CLI-131 | pass | findings/evidence/cov2-cli/CLI-131/ | exit 64 naming default, info, debug |
| CLI-057 | pass | findings/evidence/cov2-cli/CLI-057/ | rejected as not a valid Android application ID, exit 1, before device or build work |
| CLI-058 | pass | findings/evidence/cov2-cli/CLI-058/ | rejected, exit 64: 'Error: --udid is empty. ...' with usage line (no 'Invalid argument:' after K42) |
| CLI-059 | pass | findings/evidence/cov2-cli/CLI-059/ | --udid not-a-udid-at-all and --session-id "" both rejected, exit 64, plain Error: with usage line |
| CLI-060 | pass | findings/evidence/cov2-cli/CLI-060/ | exact message, exit 64 |
| CLI-061 | blocked needs a device | findings/evidence/cov2-cli/CLI-061/ | parse half holds (the quoted, emoji label parses; stops only at 'Simulator not found'); the staged flow is generated only after device resolution, so the byte-for-byte label is observable only with a device; iOS slice should take it |
| CLI-062 | pass | findings/evidence/cov2-cli/CLI-062/ | exact message, exit 64 |
| CLI-132 | pass | findings/evidence/cov2-cli/CLI-132/ | --device rejected by name as an Android option, exit 1 (emulator-9999 used instead of emulator-5554) |
| CLI-133 | pass | findings/evidence/cov2-cli/CLI-133/ | 'Flow file not found: missing.yaml', exit 1, before device work, with and without --no-build |
| CLI-134 | pass | findings/evidence/cov2-cli/CLI-134/ | all six rejected by name before any build or boot, exit 1, all in the same long form (runner start now matches build/ci/diff) |
| CLI-165 | pass | findings/evidence/cov2-cli/CLI-165/ | exact message, exit 1, before any build |
| CLI-166 | pass | findings/evidence/cov2-cli/CLI-166/ | stderr 'Error: Not authenticated. Run: grantiva auth login', stdout empty, exit 1 |
| CLI-167 | pass | findings/evidence/cov2-cli/CLI-167/ | all four refused with the Android baselines sentence, exit 1; --derived-data-path also gets that sentence (not the iOS-option rejection); adb devices unchanged, no Gradle output |
| CLI-168 | pass | findings/evidence/cov2-cli/CLI-168/ | --derived-data-path x and --scheme/--simulator accepted (Resolved line), each ends with the auth error, exit 1; nothing built (x not created) |
| CLI-169 | pass | findings/evidence/cov2-cli/CLI-169/ | --allow-device-settings and --headless rejected by name as Android options, exit 1, before any build |
| CLI-170 | pass | findings/evidence/cov2-cli/CLI-170/all.out | all 172 corpus pages print 2.1.0 with exit 0, including console releases update --version (K50 renamed the shadowing option to --release-version) |
| CLI-171 | pass | findings/evidence/cov2-cli/CLI-171/ | --quiet and --verbose: Unknown option, exit 64, usage names --project-dir and --platform |
| CLI-063 | pass | findings/evidence/cov2-cli/CLI-063/ | 18 fixtures (round-1 fixtures/ reused: every listed command, swipe direction/from/start-end with duration, extendedWaitUntil visible/notVisible) each resolve screens=1 under run and fail only at 'Simulator not found'; combined fixture likewise under diff capture |
| CLI-064 | blocked needs a device | findings/evidence/cov2-cli/CLI-064/ | both selector forms parse (screens=1, fails only at 'Simulator not found'); the staged flow is written only after device resolution, so the emitted id: selector is observable only with a device; iOS slice should take it |
| CLI-065 | pass | findings/evidence/cov2-cli/CLI-065/ | back, setPermissions, evalScript, pressKey, openLink each rejected before device work as 'grantiva.yml:5: unsupported Maestro command '<name>'' (diff capture and run), exit 1 |
| CLI-066 | blocked needs a device | findings/evidence/cov2-cli/CLI-066/ | bare scroll and scroll {direction: up} parse (screens=1, fails only at 'Simulator not found'); the swipe they map to is emitted only into the staged flow after device resolution; iOS slice should take it |
| CLI-067 | pass | findings/evidence/cov2-cli/CLI-067/ | two takeScreenshot points resolve to screens=2 |
| CLI-068 | pass | findings/evidence/cov2-cli/CLI-068/ | runFlow: sub.yaml and runFlow: {file: sub.yaml} both include the sub-flow at parse time: its takeScreenshot counts, screens=2 in each (fails only at 'Simulator not found') |
| CLI-135 | pass | findings/evidence/cov2-cli/CLI-135/ | swipe {direction: UP}, extendedWaitUntil {visible:}, bare waitForAnimationToEnd parse; run and diff capture fail only at 'Simulator not found' |
| CLI-069 | pass | findings/evidence/cov2-cli/CLI-069/ | Xcode-only copy: init writes grantiva.yml, exit 0. With one shared scheme it writes 'scheme: Landmarks' (no scheme warning); with the demo's two schemes it writes the scheme as a comment and warns 'Several schemes found: ...' (K38 behaviour). Also warns that the default simulator 'iPhone 18 Pro' exists and was not created by Grantiva |
| CLI-070 | pass | findings/evidence/cov2-cli/CLI-070/ | Gradle-only copy: writes grantiva-android.yml (platform: android, module app), exit 0. Side finding EXTRA-01: it writes emulator: Pixel_8_API_35, an AVD this host already has that Grantiva did not create, with no warning (iOS init warns in that case) |
| CLI-071 | pass | findings/evidence/cov2-cli/CLI-071/ | exact message, exit 1, no file written |
| CLI-072 | pass | findings/evidence/cov2-cli/CLI-072/ | empty dir: writes grantiva.yml, exit 0, stderr 'Warning: No Xcode project found; scheme "MyApp" is a placeholder. Edit grantiva.yml or pass --scheme.'; simulator default 'iPhone 18 Pro' is an installed iPhone type (with the not-created-by-Grantiva warning) |
| CLI-073 | pass | findings/evidence/cov2-cli/CLI-073/ | config has exactly scheme: Landmarks and bundle_id: com.kylebrowning.Landmarks |
| CLI-074 | pass | findings/evidence/cov2-cli/CLI-074/ | writes grantiva-android.yml with application_id: com.kylebrowning.landmarks |
| CLI-075 | pass | findings/evidence/cov2-cli/CLI-075/ | second init prints 'grantiva.yml already exists — skipping' on stderr, file unchanged, stdout empty (exit 0) |
| CLI-076 | pass | findings/evidence/cov2-cli/CLI-076/ | both fail naming the flag (long form), exit 1; no file written |
| CLI-077 | pass | findings/evidence/cov2-cli/CLI-077/ | Unknown option '--json', exit 64 |
| CLI-136 | pass | findings/evidence/cov2-cli/CLI-136/ | init --scheme X in an empty dir: no placeholder scheme warning (only the default-simulator warning) |
| CLI-078 | pass | findings/evidence/cov2-cli/CLI-078/ | healthy host: every Required check passes, exit 0 ('4 passed · 4 optional') |
| CLI-079 | pass | findings/evidence/cov2-cli/CLI-079/ | checks Android SDK, adb, Android Emulator, JDK (Required) and AVDs, running emulator (Advisory); exit 0 |
| CLI-080 | pass | findings/evidence/cov2-cli/CLI-080/ | ANDROID_HOME unset: ANDROID_SDK_ROOT is used (a fake ANDROID_SDK_ROOT is named in the warning), and with neither set ~/Library/Android/sdk is found |
| CLI-081 | pass | findings/evidence/cov2-cli/CLI-081/ | Xcode and Xcode Version fail (✗, Required) with fix lines; exit 1 in text and --json (with --platform ios and in an iOS project) |
| CLI-082 | pass | findings/evidence/cov2-cli/CLI-082/ | ANDROID_HOME=/nonexistent: SDK check is a warning '... (ANDROID_HOME=/nonexistent has no platform-tools/adb; unset or fix it)' with a fix line; same wording for ANDROID_SDK_ROOT=/nonexistent; exit 0 |
| CLI-083 | pass | findings/evidence/cov2-cli/CLI-083/ | scratch HOME (no credentials), no config, no git: Grantiva Auth, GitHub App, grantiva.yml, Git all advisory (●), exit 0. A booted simulator is present (the iOS slice's cov2-ios-1), so 'no booted simulator' could not be produced without touching another slice's device; the Booted Simulator check is in the Advisory section, and in CLI-026 its warning state left the exit code at 0 |
| CLI-137 | pass | findings/evidence/cov2-cli/CLI-137/ | doctor: '✗ grantiva-android.yml  could not be parsed: 5:3: ...' with fix line 'Fix the YAML in <path>', exit 1; run gives the same 5:3 parse error |
| CLI-138 | pass | findings/evidence/cov2-cli/CLI-138/ | doctor from repo/android (Gradle settings) of a scratch git work tree: '✓ Git Repository  Detected' |
| CLI-084 | pass | findings/evidence/cov2-cli/CLI-084/ | both exit 0 with 'Runner already installed at ...' and the version; no 'Extracting' narration on a current install (K45) |
| CLI-085 | fail (matrix/brief error — triage) | findings/evidence/cov2-cli/CLI-085/ | prints 'grantiva-runner 1.1.28-grantiva.11', exit 0: the bundled runner of the binary under test (c65fc17, #199). The round-1 row text still expects 1.1.28-grantiva.9; stale expectation, not a defect |
| CLI-086 | pass | findings/evidence/cov2-cli/CLI-086/ | runner stop 2>/dev/null prints nothing (only the echoed rc=0); 'No active session found.' on stderr; --json {"status": "not_running"} |
| CLI-087 | pass | findings/evidence/cov2-cli/CLI-087/ | exit 1, stdout empty: 'Error: No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`, or pass --port.' (both commands now in backticks, no 'Invalid argument:', per K46; the row's single-quote rendering is the pre-K46 text) |
| CLI-088 | pass | findings/evidence/cov2-cli/CLI-088/ | exit 1, stdout empty, 'Error: No active runner session. Start one with `grantiva runner start` or `grantiva run --keep-alive`.' |
| CLI-139 | pass | findings/evidence/cov2-cli/CLI-139/ | --timeout 0: '--timeout must be greater than zero' exit 64; --json --format xml: exact conflict message exit 64; --format yaml: exit 64 'Please provide one of 'xml' and 'json'.' |
| CLI-140 | pass | findings/evidence/cov2-cli/CLI-140/ | --json --format tree: exact conflict message exit 64; --format bogus: usage error naming tree, json, xml, exit 64 (no session lookup) |
| CLI-141 | pass | findings/evidence/cov2-cli/CLI-141/ | relative GRANTIVA_RUNNER_HOME=rh resolved against the cwd: installed under <scratch>/rh/versions/1.1.28-grantiva.11+android-drivers-2/ (with cache/wda-builds). Side finding EXTRA-02: the first install prints the path as /private/tmp/..., the second and --json as /tmp/... |
| CLI-142 | pass | findings/evidence/cov2-cli/CLI-142/ | 2.1.0 binary copy beside the Homebrew 2.0.0 bundle. Fresh home: exit 1 naming the bundle path, that it is from another release, the expected runner 1.1.28-grantiva.11 and the missing android-drivers.tar.gz ('Nothing was installed'); fresh/versions/ left empty (no stamp dir). Existing install: exit 0, sha list identical, with a warning naming the mismatch. Matches README GRANTIVA_RUNNER_HOME row at c65fc17 ('either both runner versions or the tarball it lacks') |
| CLI-091 | pass | findings/evidence/cov2-cli/CLI-091/ | exit 1, 'Error: Not authenticated. Run: grantiva auth login', stdout empty (Resolved line on stderr), nothing built |
| CLI-108 | pass | findings/evidence/cov2-cli/CLI-108/ | refused with the documented sentence, exit 1 |
| CLI-101 | pass | findings/evidence/cov2-cli/CLI-101/ | exact message before any device work (with and without --device), exit 1 |
| CLI-102 | pass | findings/evidence/cov2-cli/CLI-102/ | exit 64 in 0.025 s with the exact message; no video written |
| CLI-103 | pass | findings/evidence/cov2-cli/CLI-103/ | 'Missing expected argument '--duration <duration>'', exit 64 |
| CLI-143 | fail (matrix/brief error — triage) | findings/evidence/cov2-cli/CLI-143/ | rejected before recording, but as a usage error: 'Error: --duration must be greater than zero' with the usage line, exit 64, not the row's 'Error: Invalid argument: --duration must be greater than zero' (exit 1). The K41 fix moved the range checks into validation (B2-K41 expects record --duration -1 to exit 64 with its range message); the row text predates it |
| CLI-144 | pass | findings/evidence/cov2-cli/CLI-144/ | iOS .mp4 and extensionless, Android .mov and extensionless: exit 64 with the exact platform messages ('Try a.mov.' / 'Try a.mp4.'), nothing recorded |
| CLI-145 | pass | findings/evidence/cov2-cli/CLI-145/ | four rejections, exit 1: the three other-platform messages now in the shared long form ('... but this is an iOS project (resolved from --platform, GRANTIVA_PLATFORM, the config file, or the directory).', K43) and '--device and --emulator are mutually exclusive; pass one.' |
| CLI-146 | pass | findings/evidence/cov2-cli/CLI-146/ | exact message, exit 1 |
| CLI-104 | pass | findings/evidence/cov2-cli/CLI-104/ | exact message, exit 64 |
| CLI-147 | pass | findings/evidence/cov2-cli/CLI-147/ | both messages, exit 64, plain 'Error:' with usage line (fake serial used) |
| CLI-148 | pass | findings/evidence/cov2-cli/CLI-148/ | exact message, exit 1 |
| CLI-149 | pass | findings/evidence/cov2-cli/CLI-149/ | both 'Missing expected argument '--name <name>'', exit 64 |
| CLI-105 | pass | findings/evidence/cov2-cli/CLI-105/ | 'Missing expected argument '--name <name>'', exit 64 |
| CLI-106 | pass | findings/evidence/cov2-cli/CLI-106/ | approve and compare: 'No captures found in .grantiva/captures. Run: grantiva diff capture', exit 1 (Android names .grantiva/captures/android); no .grantiva left behind |
| CLI-150 | pass | findings/evidence/cov2-cli/CLI-150/ | 'Error: No capture found for "NoSuchScreen" in .grantiva/captures. Run: grantiva diff capture', exit 1; Home.png unchanged (sha), no baseline written |
| CLI-151 | pass | findings/evidence/cov2-cli/CLI-151/ | 'No screens configured in grantiva.yml', exit 1, with and without --no-build |
| CLI-107 | pass | findings/evidence/cov2-cli/CLI-107/ | rejected by name in the long form, exit 1, before any Gradle build |
| CLI-097 | pass | findings/evidence/cov2-cli/CLI-097/ | empty dir (no flag, ios, android): initialize + tools/list with 22 tools, every stdout line JSON-RPC, stderr empty, exit 0 |
| CLI-098 | pass | findings/evidence/cov2-cli/CLI-098/ | 'Error: Invalid argument: Project directory does not exist: /nonexistent', exit 1 |
| CLI-099 | pass | findings/evidence/cov2-cli/CLI-099/ | iOS config, no session: server starts; grantiva_tap, grantiva_screenshot, grantiva_a11y_tree return isError naming the project's .grantiva/session.json, `grantiva runner start` and `grantiva run --keep-alive`; tools/list still answers (22) |
| CLI-100 | pass | findings/evidence/cov2-cli/CLI-100/ | both configs, no --platform: server exits 1 at startup with 'Both grantiva.yml and grantiva-android.yml exist. Pass --platform ios\|android ...', stdout empty; with --platform ios it serves iOS (grantiva_context platform: ios, source: grantiva.yml) |

## Findings outside the matrix rows (recorded as fail for triage)

| ID | result | evidence | note |
|---|---|---|---|
| EXTRA-01 | fail | findings/evidence/cov2-cli/CLI-070/init.err | Android init writes emulator: Pixel_8_API_35 (an AVD present on this host that Grantiva did not create; init's default AVD name) with no warning, while iOS init warns when its default simulator name already exists and was not created by Grantiva (CLI-069/072): the K37 provenance warning is iOS-only, so a following Android run would boot and drive the user's own AVD |
| EXTRA-02 | fail | findings/evidence/cov2-cli/CLI-141/ | runner install with a relative GRANTIVA_RUNNER_HOME prints the install path as /private/tmp/... on the extracting run and as /tmp/... on later runs and in --json (same directory, two spellings); CLI-142's warning and error also use /tmp/... while the cwd is /private/tmp/... |

## Counts

365 rows in the CLI slice; 135 graded: pass 125, fail 5 (of which matrix/brief error 5), blocked 5, n/a 0. Not yet run: 230. Findings outside the matrix: 2.
