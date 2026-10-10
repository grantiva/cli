# CLI slice results: 2.1.0 regression pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (runner `grantiva-runner 1.1.28-grantiva.8`), `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`,
`GRANTIVA_SESSION_ID=reg-cli`, no `GRANTIVA_API_KEY`, no `~/.grantiva/auth.json`. Fixtures were copied from the qa/cli
worktree into the scratch dir. Device-free repros that would otherwise reach a simulator were given the explicit
non-existent UDID `00000000-0000-0000-0000-0000000000C1`, so parsing/validation runs and the command then stops at
"Simulator not found" without touching any real device. Step 4 (borrowed simulator) is not done yet.

Verdict rule: `pass` means every acceptance criterion that can be observed from the CLI without a device holds, and
the brief's main repro ran here; criteria that need a device or are unit-test requirements are named in the note.
`not-verifiable-here` means the main repro needs a simulator, emulator or live runner session.

## Step 1: C and D briefs

ID | verdict | evidence | note
--- | --- | --- | ---
C01 | not-verifiable-here | — | Needs a simulator lease and `runner install` lock contention on a device host; not attempted.
C02 | not-verifiable-here | — | Needs the agent to start and tear down emulators; not attempted.
C03 | not-verifiable-here | — | Needs a live runner session for the MCP server; Step 4 will revisit.
C04 | not-verifiable-here | — | Needs a `screens:` run on a simulator (report dir, timeout kill, continue-on-failure).
C05 | not-verifiable-here | — | Repro calls `grantiva_vrt_compare` in a project with a runner session; not attempted.
C06 | not-verifiable-here | — | Needs two booted simulators and a session; Step 4 will revisit.
C07 | pass | findings/evidence/cli/C07.txt | `swipe: {direction: UP}`, `extendedWaitUntil: {visible:}`, bare `waitForAnimationToEnd` parse and reach "Booting simulator"; `back` fails with `grantiva.yml:5: unsupported Maestro command 'back'`. README:173 lists the accepted commands and the reject behaviour. On-device execution not checked.
C08 | not-verifiable-here | — | Generated `tapOn: id:` only shows in a device run's step labels.
C09 | not-verifiable-here | — | Needs timing of a `wait: 3` step on a simulator.
C10 | not-verifiable-here | — | Needs `run --flow` against a simulator.
C11 | not-verifiable-here | — | Held for Step 4 per dispatch. Side observation: D09.txt shows `initialize` and `tools/list` (22 tools) answering in an empty dir with no session and no config, for ios and android.
C12 | pass | findings/evidence/cli/C12.txt | doctor in `both/` reports Platform as advice ("Found both ... Pass --platform ios\|android or set GRANTIVA_PLATFORM."), exit 0, which the criteria allow; `GRANTIVA_PLATFORM=windows` fails doctor, init and run with the same message; `init --platform android --scheme X` and `init --platform ios --application-id a.b` fail naming the flag and write no file.
C13 | pass | findings/evidence/cli/C13.txt | `runner stop 2>/dev/null` prints nothing; the message is on stderr; `--json` prints `{"status":"not_running"}`. The `record ... 2>/dev/null` half needs a simulator and was not checked.
C14 | pass | findings/evidence/cli/C14.txt | `--frames-at a,b` exits 64 in 0.014 s, no file written; extensionless `--output` and `.mp4` on iOS exit 64 before recording with "--output must end in .mov on iOS"; help states the accepted extensions. A real recording was not made.
C15 | pass | findings/evidence/cli/C15.txt | Exact message `grantiva.yml: screen "Diag": swipe direction "diagonal" is not one of up, down, left, right` before any device work; `swipe: UP` is accepted.
C16 | pass | findings/evidence/cli/C16-*.txt | Reversed expectation (Step 3): unknown event names are not rejected locally (fail with "Not authenticated"); blank events and http URLs still fail locally with exit 64.
C17 | not-verifiable-here | — | Repro calls `grantiva_script` through a live runner session.
C18 | pass | findings/evidence/cli/C18.txt | Android: `No grantiva-android.yml here. Create one with grantiva init --platform android.`; iOS: `No grantiva.yml here. Create one with grantiva init.`; empty files: `No screens or flows configured in grantiva.yml` / `grantiva-android.yml`.
C19 | pass | findings/evidence/cli/C19.txt | stderr shows both `grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)` and `grantiva.yml:4: unknown key "screen" (did you mean "screens"?)` before the error; doctor reports the same as a Project warning; a Maestro-format file gets no warning.
C20 | pass | findings/evidence/cli/C20.txt | doctor: `✗ grantiva-android.yml  could not be parsed: 5:3: ...` with "Fix the YAML in <path>", exit 1; run reports the same parse error.
C21 | pass | findings/evidence/cli/C21.txt | The `sim boot` and `ui a11y` strings are gone; GrantivaError and the binary carry `Run: grantiva simulator ensure --name "<device>"` and `Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) ...`; doctor's fix uses the newest iPhone. The MCP `grantiva_tap` isError half needs a session and was not checked.
C22 | pass | findings/evidence/cli/C22.txt | `simulator sessions --json` (the iOS agent's two leases) and `emulator sessions --json` print ISO 8601 strings (`"acquiredAt" : "2026-10-10T21:27:23Z"`, `"startedAt" : "2026-10-10T21:27:36Z"`). Read-only listing; nothing was changed.
C23 | pass | findings/evidence/cli/C23.txt | Both stale `ANDROID_HOME` and stale `ANDROID_SDK_ROOT` produce the warning with the exact wording. (JDK ✗ in that output only because this shell did not set JAVA_HOME.)
C24 | pass | findings/evidence/cli/C24.txt | Empty dir: stderr `Warning: No Xcode project found; scheme "MyApp" is a placeholder. Edit grantiva.yml or pass --scheme.`; none with `--scheme X` or with a detected project; `simulator: iPhone 18 Pro` is an installed device type.
C25 | pass | findings/evidence/cli/C25.txt | No credentials existed, so nothing was moved. `Not logged in; no credentials at ~/.grantiva/auth.json.`, exit 0; `--json` gives `success: true`, `message: "No stored credentials"`, `removed: false`.
C26 | regressed | findings/evidence/cli/C26.txt | See below: README:99 still says `--continue-on-failure` and `--timeout` do not apply to `screens:` while README:101 says they do.
D01 | not-verifiable-here | findings/evidence/cli/D01.txt | Held for Step 4 (`hierarchy --json` output needs a session). Device-free parts hold: `--json --format xml` is a usage error (exit 64) on both commands, `runner stop --json` prints JSON, README:368-370 and docs/dump-hierarchy.md:38,51 document `--json`.
D02 | pass | findings/evidence/cli/D02-examples.txt, D02-table.txt | All 62 README command examples name real subcommands whose help lists every flag used. The Commands table lists the emulator commands, `console`, and `runner dump-hierarchy`; run/record/build say "simulator or emulator"; `simulator cleanup`, `delete` and `sessions` match help word for word. Minor wording differences are listed under Step 2 below.
D03 | pass | findings/evidence/cli/D03.txt | README:415-416 `grantiva run --simulator "$udid" --flow flows/login.yaml` parses in a scratch iOS project (gets to xcodebuild / simulator lookup, no usage error); the old `--device X flows/` form is a usage error.
D04 | pass | findings/evidence/cli/D04.txt | Overviews: "The Grantiva CLI for iOS and Android developers.", "Run Maestro flows against a simulator or emulator.", "Build the app for a simulator (xcodebuild) or emulator (Gradle)."; `--no-build` says "device"; README:3 matches.
D05 | pass | findings/evidence/cli/D05.txt | `ls CHANGELOG.md` fails (removed); `--version` is 2.1.0.
D06 | pass | findings/evidence/cli/D06.txt | docs/android-environment.md §CI says `ci run` refuses Android, points to `diff capture\|compare\|approve`, keeps the self-hosted note; `ci run --platform android` refuses with that message.
D07 | pass | findings/evidence/cli/D07.txt | docs/android.md §Devices states the selection order with no "Only running emulators" sentence; the EmulatorManager.swift:184 doc comment says the same.
D08 | pass | findings/evidence/cli/D08.txt | `--ready-file does/not/exist/x.ready` creates the parents and writes `status: failed`; help and README:87 say missing parent directories are created.
D09 | pass | findings/evidence/cli/D09.txt | docs/mcp.md lists 22 tools, matching `tools/list` exactly (ios and android), marks `grantiva_test` iOS only and `grantiva_emulator_*` Android only, and has a Session column.

### Regressed detail

**C26.** Brief criterion: "Note that until C04 is fixed, these flags apply only to `flows:`/`--flow`; say so, or drop the
note once C04 lands." C04 has landed (README:101: "`--timeout` and `--continue-on-failure` also apply to `screens:`;
with `--continue-on-failure` a failed screens session is reported and the configured flows still run"), but the old
note was not dropped. README:99 still reads: "`--continue-on-failure` and `--timeout` apply to flow files (`flows:` in
the config, or `--flow`). A suite that runs only the configured `screens:` does not read these two flags: it uses a
fixed 300 s timeout." The README now contradicts itself two lines apart. The other C26 criteria hold: README:95-97
describe `--snapshot`, `--continue-on-failure` (fail-fast default) and `--timeout` (default 600, minimum 30, ignored
under `--keep-alive`); `run --help` says "Minimum 30."; `--timeout 0` exits 64.

## Step 2: help and version surface

ID | verdict | evidence | note
--- | --- | --- | ---
S2-auto-accept | pass | findings/evidence/cli/version-surface.txt | `run --help \| grep -c auto-accept` is 0.
S2-version | pass | findings/evidence/cli/version-surface.txt | `--version` 2.1.0.
S2-runner-version | pass | findings/evidence/cli/version-surface.txt | `runner version` is `grantiva-runner 1.1.28-grantiva.8`.
S2-help-files | pass | findings/evidence/cli/help-*.txt | Help captured for every top-level command and the nested ones used here. `sessions` and `update` are not top-level commands: `grantiva sessions --help` / `update --help` print the top-level help (exit 0, so help-sessions.txt and help-update.txt equal help-top.txt), and `grantiva sessions` exits 64. The session listings are `simulator sessions` and `emulator sessions`.
S2-readme-vs-help | pass | findings/evidence/cli/D02-examples.txt, D02-table.txt | No README example uses a missing subcommand or flag.

README vs help wording differences (not failures of any brief's criterion; recorded as findings):
- README:338 `grantiva init — Generate grantiva.yml`; help: "Generate grantiva.yml (iOS) or grantiva-android.yml (Android) in the current directory." The README row omits Android.
- README:311 `grantiva hierarchy — Dump the live UI hierarchy of a keep-alive session`; help: "Dump the UI hierarchy of a booted simulator or emulator without relaunching the app."
- README:312 `grantiva build — Build the app for a simulator (xcodebuild) or emulator (Gradle)` is the `build build` abstract; `grantiva build --help` says "Build and optionally install the app to a simulator or emulator."
- README:314 `ci run` says "(build -> capture -> diff -> upload)"; help says "capture screenshots, compare against baselines, upload results".

## Step 3: webhook event validation is server-side (C16 reversal)

ID | verdict | evidence | note
--- | --- | --- | ---
S3-unknown-event | pass | findings/evidence/cli/C16-unknown-event.txt | `webhooks create https://example.com/hook --event not.an.event` and `webhooks update wh_1 --event not.an.event` both fail with `Not authenticated. Run: grantiva auth login` (exit 1), not with a local event-name error. `--event` help: "The server validates event types."
S3-blank-event | pass | findings/evidence/cli/C16-blank-event.txt | `--event ""` and `--event "   "` on create, and `--event ""` on update: `Event types must not be blank.`, exit 64.
S3-http-url | pass | findings/evidence/cli/C16-http-url.txt | `create http://example.com/hook`: `URL must be an https URL.`, exit 64.
S3-events-subcommand | pass | findings/evidence/cli/C16-events-subcommand.txt | `console webhooks events` no longer exists (exit 64); README and docs do not mention it.
