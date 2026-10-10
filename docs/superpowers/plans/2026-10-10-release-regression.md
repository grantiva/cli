# Release Regression Pass for 2.1.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove that grantiva/cli `main` at `a278b77` (version 2.1.0, bundling grantiva-runner 1.1.28-grantiva.8) still satisfies every acceptance criterion from the 2026-10-09 QA campaign and the follow-up round, on iOS and Android, through the install path a user actually takes, so 2.1.0 can be tagged.

**Architecture:** Task 0 builds one release binary from `main`, exercises the runner upgrade path in a cloned runner home, and creates one worktree per slice. Tasks 1-3 run three verification agents (CLI, iOS, Android) in parallel, each re-checking the acceptance criteria of the briefs in its slice plus the full landmarks-demo flow set. Task 4 merges their results, writes a brief per regression, and produces the release verdict.

**Tech Stack:** grantiva CLI (Swift, release build), landmarks-demo (SwiftUI app and Compose app, Maestro-format flows), Xcode 27.0 with iOS 26.0 and 27.0 runtimes, Android SDK 35 emulator.

**Spec:** `docs/superpowers/specs/2026-10-09-qa-campaign-design.md` (what each feature must do), with the per-bug acceptance criteria in `docs/superpowers/plans/2026-10-09-qa-issues/*.md` as the binding requirements for this pass. Last round's results: `docs/superpowers/plans/2026-10-09-qa-campaign-report.md` and `docs/superpowers/plans/2026-10-09-qa-feature-matrix.md`.

## Global Constraints

- Target commit: `a278b77` on `main` (`git log --oneline -1 origin/main` prints `a278b77 Drop --no-auto-accept-alerts ...`). One release binary, built once by Task 0 at `/Users/kyle/.grantiva-qa/bin/grantiva`; every agent calls it as `$GRANTIVA`. Agents never run `swift build`.
- Runner home for this pass: `GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner`, exported in every agent shell. It is a clone of the user's real home made by Task 0. NEVER unset it, NEVER write under `~/.grantiva/runner`, NEVER run `grantiva runner install` without it set.
- Demo apps: `/Users/kyle/Developer/landmarks-demo/{ios,android}` (iOS bundle `com.kylebrowning.Landmarks`, scheme `Landmarks (UI Testing)`; Android application id `com.kylebrowning.landmarks`, module `app`, variant `freeDebug`). Copy the directory you need to your scratch dir before building; never commit into landmarks-demo. Flows are in `.maestro/` (01-12 plus 99-crash); `grantiva.yml` lists flows 01-12 and the `screens:`.
- Devices and names. iOS agent: simulators `qa-reg-ios-1` (iPhone 17, runtime 26.0) and `qa-reg-ios-2` (iPhone 17, runtime 27.0), created with `$GRANTIVA simulator ensure --name <name> --device-type "iPhone 17" --runtime <26.0|27.0>` (prints the UDID), removed with `$GRANTIVA simulator teardown --udid <udid>`. Android agent: AVD `qa-reg-android` via `$GRANTIVA emulator ensure --name qa-reg-android` (note the serial it prints), removed with `$GRANTIVA emulator teardown --serial <serial>` and then `avdmanager delete avd -n qa-reg-android`. CLI agent: no devices unless a step says otherwise; it then borrows the iOS agent's `qa-reg-ios-1` by UDID after the iOS agent reports. Session IDs: `GRANTIVA_SESSION_ID=reg-ios`, `reg-android`, `reg-cli`.
- NEVER boot, shut down, erase, delete or send any command to the simulator `iPhone 17 Pro` (`B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C`); always pass an explicit `--simulator <udid>` / `--udid` / `--device <serial>` so nothing falls back to "first booted device". If `adb devices` lists `emulator-5554` before you created anything, it is the user's `Pixel_8_API_35`: you may use it and must never shut it down. Never kill a process you did not start; never run `simulator teardown --all`, `emulator teardown --all`, `xcrun simctl shutdown all`, `adb emu kill` on a device you did not start.
- Android shells always begin with: `export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"; export ANDROID_HOME="$HOME/Library/Android/sdk"; export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"`.
- No Grantiva account: `GRANTIVA_API_KEY` must be unset in every shell.
- Agents never edit files under `Sources/`, `Tests/`, `.github/` or `README.md`. Findings are files under the agent's worktree `findings/`, never GitHub issues.
- Agents work only in the worktree named in their dispatch (`.worktrees/reg-<slice>`, branch `reg/<slice>`), commit there, and never push. Commits are SSH-signed by the global git config; no `Co-Authored-By`, no `Generated with` lines, ever. Never `git stash`.
- Write-ups never mention any other project the runner is related to; describe behaviour in terms of grantiva and grantiva-runner only.
- Scratch dir for everything temporary: `/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/<session>/scratchpad/reg-<slice>/` (the orchestrator fills in `<session>` in each dispatch).

## Review Focus

Behaviour this release changed that no single brief re-checks on its own. Each line names the task that covers it.

1. Upgrading an install that already holds runner 1.1.18-grantiva.7 and locally built WebDriverAgent caches: the new version is extracted, the old caches survive, the new `-wda16.12.8` caches are present, and `runner version` reports 1.1.28-grantiva.8. Task 0, Step 3.
2. A first `grantiva run` on iOS 26.0 and on 27.0 after the upgrade uses the embedded cache (`Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8)` / `27.0`), with no WebDriverAgent build. Task 2, Step 2.
3. An app alert ("Discard changes?") stays up until the flow taps it, while a system prompt is still answered for the flow, and `grantiva run --help` no longer lists `--no-auto-accept-alerts`. Task 2, Step 3 (flow 04) and Task 1, Step 2.
4. Two simulators running flows at the same time from two shells, each with its own WebDriverAgent session and port, both passing. Task 2, Step 4.
5. Webhook event names are no longer validated locally: an unknown event reaches the server path (without an account, the command fails for lack of credentials, not for the event name). Task 1, Step 3.

---

### Task 0: Shared binary, runner upgrade path, worktrees

Run by the orchestrating session.

**Files:**
- Create: `/Users/kyle/.grantiva-qa/bin/grantiva`, `/Users/kyle/.grantiva-qa/VERSION`, `/Users/kyle/.grantiva-qa/runner/` (cloned runner home)
- Create: worktrees `.worktrees/reg-cli`, `.worktrees/reg-ios`, `.worktrees/reg-android` on branches `reg/cli`, `reg/ios`, `reg/android` from `regression-2.1.0`
- Create: `findings/task0-upgrade.md` in `.worktrees/regression`

- [ ] **Step 1: Build the release binary from main**

```bash
cd /Users/kyle/Developer/grantiva-cli/.worktrees/regression
git log --oneline -1   # a278b77 (+ this plan's commit on top)
swift build -c release 2>&1 | tail -1
mkdir -p ~/.grantiva-qa/bin && cp .build/release/grantiva ~/.grantiva-qa/bin/grantiva
~/.grantiva-qa/bin/grantiva --version | tee ~/.grantiva-qa/VERSION
```
Expected: `Build complete!`; VERSION says 2.1.0.

- [ ] **Step 2: Clone the user's runner home so the upgrade path can be exercised without touching it**

```bash
rm -rf ~/.grantiva-qa/runner
cp -c -R ~/.grantiva/runner ~/.grantiva-qa/runner      # APFS clone, read-only use of the source
cat ~/.grantiva-qa/runner/version                      # 1.1.18-grantiva.7+android-drivers-2
ls ~/.grantiva-qa/runner/versions ~/.grantiva-qa/runner/cache/wda-builds
```
Expected: the clone holds the old stamp, one `versions/` entry and the pre-existing `sim-ios*` cache directories (record the list).

- [ ] **Step 3: Run the upgrade and verify it**

```bash
export GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner GRANTIVA_SESSION_ID=reg-setup; unset GRANTIVA_API_KEY
~/.grantiva-qa/bin/grantiva runner install 2>&1 | tail -3
~/.grantiva-qa/bin/grantiva runner version
cat ~/.grantiva-qa/runner/version
ls ~/.grantiva-qa/runner/versions
ls ~/.grantiva-qa/runner/cache/wda-builds
ls ~/.grantiva-qa/runner/versions/*/drivers/android
```
Expected: `grantiva-runner 1.1.28-grantiva.8`; version file `1.1.28-grantiva.8+android-drivers-2`; `versions/` has the new stamp (the old one may remain); `cache/wda-builds` lists every directory recorded in Step 2 plus `sim-ios26.0-iphone-wda16.12.8`, `sim-ios26.2-...`, `sim-ios26.4-...`, `sim-ios27.0-iphone-wda16.12.8`; the two uiautomator2 APKs are present. Write the before/after listings and the verdict to `.worktrees/regression/findings/task0-upgrade.md`. Any deviation is Review Focus item 1 failing: stop and report before dispatching agents.

- [ ] **Step 4: Create the slice worktrees**

```bash
cd /Users/kyle/Developer/grantiva-cli
for s in cli ios android; do git worktree add -q .worktrees/reg-$s -b reg/$s regression-2.1.0; mkdir -p .worktrees/reg-$s/findings/evidence; done
git worktree list | grep reg-
```

- [ ] **Step 5: Commit Task 0's findings on `regression-2.1.0`**

```bash
cd /Users/kyle/Developer/grantiva-cli/.worktrees/regression && git add findings/task0-upgrade.md && git commit -q -m "Record the runner upgrade check for the 2.1.0 regression pass" && git cat-file commit HEAD | grep -q '^gpgsig' && echo signed
```

---

### Task 1: CLI slice

Agent, worktree `.worktrees/reg-cli`, `GRANTIVA_SESSION_ID=reg-cli`, no devices except Step 4.

**Files:**
- Create: `findings/cli-results.md`, `findings/evidence/cli/*`

**Interfaces:**
- Consumes: `$GRANTIVA`, `GRANTIVA_RUNNER_HOME`, the briefs `C01`-`C26` and `D01`-`D09` in `docs/superpowers/plans/2026-10-09-qa-issues/`.
- Produces: `findings/cli-results.md` with one row per brief: `ID | verdict (pass / regressed / not-verifiable-here) | evidence path | note`, plus the rows from Steps 2 and 3.

- [ ] **Step 1: Re-verify every C and D brief's acceptance criteria**

For each of the 35 briefs, read its "Acceptance criteria" and "Repro" sections, run the repro against `$GRANTIVA` from a scratch copy of the relevant demo app (or an empty directory when the brief says so), capture the command output to `findings/evidence/cli/<ID>.txt`, and record the verdict. Briefs whose criteria need a device (`C01` simulator leases, `C02` emulator ledger, `C03`/`C05`/`C06`/`C11` MCP with a live session) get `not-verifiable-here` unless Step 4 covers them. `D05` (changelog) is satisfied by the CHANGELOG having been removed: record `pass` with `ls CHANGELOG.md` failing. `C16` is now server-side: see Step 3.

- [ ] **Step 2: Help and version surface**

```bash
$GRANTIVA run --help | grep -c 'auto-accept'          # expect 0
$GRANTIVA --version                                    # 2.1.0
$GRANTIVA runner version                               # grantiva-runner 1.1.28-grantiva.8
$GRANTIVA --help > findings/evidence/cli/help-top.txt
for c in run diff record hierarchy doctor init simulator emulator runner mcp sessions update; do $GRANTIVA $c --help > findings/evidence/cli/help-$c.txt 2>&1; done
```
Compare every README command example against the help files (brief `D02`); record mismatches as findings.

- [ ] **Step 3: Webhook event validation is server-side (C16 reversal)**

Find the command that takes `--event` (`grep -l -- '--event' findings/evidence/cli/help-*.txt`). Run it with an unknown event name and no credentials, and with a blank event, and with an `http://` URL. Expected: the unknown name is NOT rejected locally (the failure, if any, is about missing credentials or the network); blank and non-https still fail locally with the existing messages. Save outputs to `findings/evidence/cli/C16-*.txt`.

- [ ] **Step 4: Session-aware commands with a borrowed simulator**

Only after the orchestrator passes you the iOS agent's `qa-reg-ios-1` UDID. From the scratch iOS app copy: `$GRANTIVA runner start --simulator <udid>` (note the session), then `$GRANTIVA context`, `$GRANTIVA sessions --json`, `$GRANTIVA hierarchy --udid <udid> --json | head -c 400`, `$GRANTIVA runner stop --udid <udid>`. This covers `C03`, `C06`, `C11`, `C22`, `D01`. Never start a second session on that simulator while the iOS agent reports it busy.

- [ ] **Step 5: Commit**

```bash
git add findings && git commit -q -m "CLI slice results for the 2.1.0 regression pass" && git cat-file commit HEAD | grep -q '^gpgsig' && echo signed
```

---

### Task 2: iOS slice

Agent, worktree `.worktrees/reg-ios`, `GRANTIVA_SESSION_ID=reg-ios`, owns the iOS slot.

**Files:**
- Create: `findings/ios-results.md`, `findings/evidence/ios/*`

**Interfaces:**
- Consumes: `$GRANTIVA`, `GRANTIVA_RUNNER_HOME`, briefs `I01`-`I19`, `C07`-`C10`, `C15`, `A13` (iOS half), scratch copy of `landmarks-demo/ios`.
- Produces: `findings/ios-results.md` rows per brief and per flow (26.0 and 27.0 columns), plus the concurrency check result; reports the `qa-reg-ios-1` UDID to the orchestrator as soon as it exists.

- [ ] **Step 1: Simulators and app**

```bash
UDID1=$($GRANTIVA simulator ensure --name qa-reg-ios-1 --device-type "iPhone 17" --runtime 26.0 | tail -1)
UDID2=$($GRANTIVA simulator ensure --name qa-reg-ios-2 --device-type "iPhone 17" --runtime 27.0 | tail -1)
cd <scratch>/ios && $GRANTIVA build install --simulator $UDID1 && $GRANTIVA build install --simulator $UDID2
```
Report `$UDID1` in your first status line.

- [ ] **Step 2: Full flow set on both runtimes, cache hit required**

```bash
$GRANTIVA run --simulator $UDID1 --no-build 2>&1 | tee findings/evidence/ios/run-26.0.txt
$GRANTIVA run --simulator $UDID2 --no-build 2>&1 | tee findings/evidence/ios/run-27.0.txt
grep -o 'Using cached GrantivaAgent build ([^)]*)\|Building GrantivaAgent for the first time' findings/evidence/ios/run-2*.txt
```
Expected: all 12 configured flows and the screens pass on both; the grep shows the `sim-ios26.0-iphone-wda16.12.8` and `sim-ios27.0-iphone-wda16.12.8` cache hits and no first-time build. Then `--flow .maestro/99-crash.yaml` on `$UDID1`: it must fail at `launchApp` or the first step after it with a message naming the crash, not pass. Copy `.grantiva/captures/` into `findings/evidence/ios/captures-<runtime>/`.

- [ ] **Step 3: Alert behaviour (I04) and the follow-up round's repros**

Run flow 04 five times in a row on `$UDID1` (`for i in 1 2 3 4 5; do $GRANTIVA run --simulator $UDID1 --no-build --flow .maestro/04-discard.yaml; done`): 5/5 pass with the "Discard changes?" alert answered by the flow's tap. Then `A02`'s iOS half (flow 02 passes, and a copy of flow 02 with `from: "No Such Row"` fails at the swipe), `I-selectors` (flow 10 with `LANDMARKS_SEED=many` via `--env`, flow 12, and a Settings flow `appId: com.apple.Preferences` with `tapOn: {id: General}` and `assertVisible: {id: clock}` on the caching screen), `C08`, `C09`, `C10`, `C07`, `C15` as their briefs describe.

- [ ] **Step 4: Two simulators at once (I01)**

In two shells started within 5 s of each other: `$GRANTIVA run --simulator $UDID1 --no-build --flow .maestro/01-browse.yaml` and the same for `$UDID2`. Both must pass; save both outputs and `ls $GRANTIVA_RUNNER_HOME/cache/wda-builds/*/devices/` showing one directory per UDID.

- [ ] **Step 5: Re-verify every I brief**

For each of `I01`-`I19`, run the brief's repro and record the verdict and evidence like Task 1. `I02`, `I03`, `I19` use `grantiva diff`; `I05`, `I06`, `I17` use the MCP tools through `$GRANTIVA mcp` (follow the brief); `I08`, `I09`, `I10`, `I14` create and tear down their own extra simulators named `qa-reg-ios-3`/`-4` and must delete them before the step ends.

- [ ] **Step 6: Teardown and commit**

```bash
$GRANTIVA simulator teardown --udid $UDID1; $GRANTIVA simulator teardown --udid $UDID2
xcrun simctl list devices | grep -c qa-reg-     # expect 0
git add findings && git commit -q -m "iOS slice results for the 2.1.0 regression pass" && git cat-file commit HEAD | grep -q '^gpgsig' && echo signed
```
Only tear down `$UDID1` after the orchestrator confirms the CLI agent has finished Task 1 Step 4.

---

### Task 3: Android slice

Agent, worktree `.worktrees/reg-android`, `GRANTIVA_SESSION_ID=reg-android`, owns the Android slot.

**Files:**
- Create: `findings/android-results.md`, `findings/evidence/android/*`

**Interfaces:**
- Consumes: `$GRANTIVA`, `GRANTIVA_RUNNER_HOME`, briefs `A01`-`A13`, `D06`, `D07`, `C02`, scratch copy of `landmarks-demo/android`.
- Produces: `findings/android-results.md` rows per brief and per flow.

- [ ] **Step 1: Emulator and app**

```bash
adb devices                                            # note whether emulator-5554 already exists (user's: use, never stop)
SERIAL=$($GRANTIVA emulator ensure --name qa-reg-android | grep -o 'emulator-[0-9]*' | tail -1)
cd <scratch>/android && $GRANTIVA build install --device $SERIAL
```

- [ ] **Step 2: Full flow set**

```bash
$GRANTIVA run --device $SERIAL --no-build 2>&1 | tee findings/evidence/android/run.txt
$GRANTIVA run --device $SERIAL --no-build --flow .maestro/99-crash.yaml 2>&1 | tee findings/evidence/android/run-99.txt
```
Expected: 12 flows and screens pass; 99-crash fails at `launchApp` with `java.lang.RuntimeException: LANDMARKS_CRASH_ON_LAUNCH` in the message. Copy captures to `findings/evidence/android/captures/`.

- [ ] **Step 3: The follow-up round's Android repros**

`A01`: `--env LANDMARKS_NOTE="a=b c"` shows the note verbatim under the Deep Links title (flow 07 or a one-step flow with `assertVisible: "a=b c"`), and `--env Q="it's"` launches without a shell error; `adb logcat -d | grep extras` saved as evidence. `A02`: flow 02 passes; a copy with `from: "No Such Row"` fails at the swipe step with element-not-found after the lookup timeout. `A13`: screens tap exact match per brief.

- [ ] **Step 4: Re-verify every A brief plus D06, D07, C02**

Per brief, as in Task 1. `C02` and `D07` involve `emulator` subcommands: create `qa-reg-android-2` if the brief needs a second AVD and delete it before the step ends.

- [ ] **Step 5: Teardown and commit**

```bash
$GRANTIVA emulator teardown --serial $SERIAL && avdmanager delete avd -n qa-reg-android
adb devices; emulator -list-avds | grep -c qa-reg      # expect 0 qa-reg AVDs
git add findings && git commit -q -m "Android slice results for the 2.1.0 regression pass" && git cat-file commit HEAD | grep -q '^gpgsig' && echo signed
```
If `emulator-5554` was the user's `Pixel_8_API_35`, it is left running.

---

### Task 4: Merge, briefs for regressions, release verdict

Run by the orchestrating session after Tasks 1-3 report.

**Files:**
- Modify: `.worktrees/regression` (merge `reg/cli`, `reg/ios`, `reg/android`)
- Create: `docs/superpowers/plans/2026-10-10-regression-issues/<ID>-<slug>.md` per regression, `docs/superpowers/plans/2026-10-10-release-regression-report.md`

- [ ] **Step 1: Merge the slice branches**

```bash
cd /Users/kyle/Developer/grantiva-cli/.worktrees/regression
for s in cli ios android; do git merge --no-ff -q reg/$s -m "Merge reg/$s results"; done
ls findings
```

- [ ] **Step 2: Triage**

Every `regressed` row becomes a brief in `docs/superpowers/plans/2026-10-10-regression-issues/` with the same sections as last round's briefs (Expected, Actual, Repro, Evidence, Suspected cause, Acceptance criteria), named `R<nn>-<slug>.md`, citing the original brief ID. A `regressed` row whose evidence shows the original brief's acceptance criteria were wrong gets a note in the report instead of a brief.

- [ ] **Step 3: Report and verdict**

Write `docs/superpowers/plans/2026-10-10-release-regression-report.md`: target commit, binary version, runner version and upgrade check (from `findings/task0-upgrade.md`), a table per slice (briefs checked / pass / regressed / not-verifiable, flows run per runtime, cache-hit confirmation, concurrency result), the list of regression briefs, host state after cleanup (`xcrun simctl list devices | grep qa-reg` empty, no `qa-reg` AVDs, `iPhone 17 Pro` untouched), and the verdict: `RELEASE 2.1.0: GO` when there are zero regression briefs of severity crash or wrong-result, otherwise `NO-GO` with the blocking brief IDs.

- [ ] **Step 4: Commit and push the regression branch**

```bash
git add -A docs/superpowers/plans/2026-10-10-regression-issues docs/superpowers/plans/2026-10-10-release-regression-report.md
git commit -q -m "Regression pass for 2.1.0: report and briefs" && git cat-file commit HEAD | grep -q '^gpgsig' && echo signed
git push -u origin regression-2.1.0
```
Then tell the user the verdict, the report path, and (on GO) that tagging `v2.1.0` on `a278b77` is the next step; the release workflow checks the tag against `Version.swift`, which already declares 2.1.0.
