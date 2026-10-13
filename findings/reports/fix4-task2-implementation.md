# Task 2 implementation report: Android gestures and lifecycle

Status: source, scoped review, CI, and required software/GPU acceptance are complete at the pushed head; the draft PR awaits controller merge.

## Identity

- Runner base: `e5cba28c8ea9fe4ae685b15ffa528bc376b5d3b7`
- Runner head: `59184b954eded5f09125afebf08b98e18fa313df`
- Branch: `fix4/gestures-lifecycle`; the worktree is clean and the same head is pushed to `grantiva/fix4/gestures-lifecycle` (draft PR 25).
- The first implementation commit was `4d425170b4522c61952597b802ff5212b97ff418`; the review-deadline fix is `d238f660635865fd5837d825ecf8147633c200ef`; lint-only removal of three superseded private wrappers is `7db530ff58188579bd1ae83b9e225e176555cce4`; ordinary-context preservation fix 2 is `59184b954eded5f09125afebf08b98e18fa313df`.
- Scoped home: `/private/tmp/grantiva-fix4-2.WiwpaS/runner-home`, assigned to both `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME` for live work. The QA CLI remained frozen.
- Final live runner binary: SHA-256 `71d87e735750f94448404e243ecfb2778252a3f52e40036a057d5fbeb7e0453a`, built from clean `59184b954eded5f09125afebf08b98e18fa313df` with `vcs.modified=false`. Exact Go build identity is retained in `findings/evidence/fix4-2/final-binary-fix2-identity.txt`; prior binary identities remain immutable historical evidence.

## RED and GREEN

The original focused RED established the requested semantics: non-ADB swipe forms emitted no held action, the parser had no `SwipeStep.Engine`, ineffective force-stop passed and disarmed the crash watch, and post-swipe target checks did not exist. The first required-package RED also exposed shell-routing assertions and stop fakes that did not transition to stopped. Its terminal stream was not retained; this limitation remains explicit and was not reconstructed after implementation.

Independent source review then found two additional semantic deadline gaps at `4d425170`: the stop loop's wall-clock deadline did not bound synchronous adb shell work, and the stable target's two-second context did not cover attribute/bounds reads or prevent a late action. The retained review RED command used a fresh empty home for both home variables and an unset API key:

```sh
env -u GRANTIVA_API_KEY \
  GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" \
  go test ./pkg/driver/uiautomator2 ./pkg/uiautomator2 \
  -run 'TestStopAppCancelsStalledPostconditionShells|TestPostSwipeTapSlowSecondBoundsReadDoesNotTapLate|TestPostSwipeTapParentCancellationStopsBoundsAndDoesNotTap' \
  -count=1 -v
```

Pre-fix observations were literal: blocked pidof and dumpsys reads returned only after the 300 ms safety release despite a 50 ms stop bound, and a held second rect returned after the client's ten-second floor. The parent-cancellation stable-target sibling already passed. Raw immutable evidence is `findings/evidence/fix4-2/review-fix-red.{out,err}` with `review-fix-red-metadata.txt`.

The final focused GREEN adds blocked force-stop, pidof, and foreground probes; parent cancellation and owned shell completion; real HTTP cancellation of a slow second rect with zero click requests; parent cancellation with zero clicks; a separately budgeted 1500 ms long press; hard UIA2 request cancellation; refused-connection no-recovery behavior; and ordinary soft-deadline/reconnect compatibility. Exact command and output are retained in:

- `findings/evidence/fix4-2/review-fix-green-v2-metadata.txt`
- `findings/evidence/fix4-2/review-fix-green-v2.out`
- `findings/evidence/fix4-2/review-fix-green-v2.err`

Fix-round-2 adds two production semantic regressions. At `7db530f`, an expired unmarked soft context made ordinary Element Text/Attribute/Rect fail before transport, and the stepScope sentinel caused a blocked detail Text to ignore the client's real cancellation and issue a subsequent Rect. Raw RED is `review-fix2-red.{out,err}` plus metadata. GREEN preserves unmarked DeadlineExceeded through the transport floor, rejects explicit cancellation and every hard expiry, restores generic selector loop checks to cancellation-only, and dispatches detail reads through ordinary element methods for stepScope versus context methods for owned wait/hard contexts. The real-client regression enters through `findElementOnce` and observes prompt server-side Text cancellation with zero Rect requests. Raw focused evidence is `review-fix2-green.{out,err}` plus metadata.

The final exact-source package command was:

```sh
env -u GRANTIVA_API_KEY \
  GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" \
  go test ./pkg/uiautomator2 ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/core/... -count=1
```

Latest fix-round-2 results: shared UIA2 `14.167s`, Android driver `207.263s`, executor `122.162s`, core `0.594s`, exit 0. The fresh home was verified empty before and after, then removed. Raw output and exact metadata are `review-fix2-full-green.{out,err}` and `review-fix2-full-green-metadata.txt`; the prior v2 capture remains immutable.

The final vet command used a separate fresh empty dual home with the API key unset:

```sh
go vet ./pkg/uiautomator2 ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/core/...
```

It exited 0; latest stdout/stderr and empty-home metadata are `review-fix2-vet.{out,err}` and `review-fix2-vet-metadata.txt`. Earlier passing package/vet captures are retained and were not overwritten.

## Implementation

- All direction, start/end, absolute-coordinate, distance, and selector swipes use the shared held W3C drag. Only literal `engine: adb` selects `input swipe`.
- The shared held-action builder distributes the remainder among pointer moves, preserving exact requested durations such as 375 ms for ordinary existing gestures and the new swipe routes.
- A successful swipe arms only the immediately following selector tap. That tap resolves fresh app-node bounds until two positive reads agree. The state is cleared after consumption and at flow boundaries; callbacks and stale app state are never regraded as success.
- Stable-target lookup now applies a distinct hard operation context to selector lookup, attributes, text, page source, and rect reads. A hard request honors its own deadline and bypasses context-free reconnect recovery. Expiry/cancellation is checked again before dispatch, so no action starts late.
- Click and long-click dispatch receives a new parent-derived action context after the stable decision. A click retains the default request budget; a long press gets at least the default budget or its requested duration plus two seconds. This preserves legitimate held-action duration independently of the two-second stabilization window while retaining parent cancellation.
- `stopApp` derives one context from the flow parent and the two-second verification budget before force-stop. It passes that same context through `ShellContext`, retries, pidof/package UID/ps, exact-package foreground reads, and the poll wait. A canceled adb child completes before return. Failures include the application ID and leave the crash watch armed; only a verified exact-package stop disarms it.
- Ordinary UIA2 step deadlines remain soft and ordinary refused connections still recover/retry. Task 1's named failure-capture wrapper now delegates to the shared hard-deadline transport behavior, preserving bounded captures without applying it to unrelated ordinary requests.
- Public driver interfaces, flags, YAML spelling, report JSON, and exact duration parsing are unchanged.

The scope additions are owned and narrow. `pkg/flow/step.go` carries the already documented `engine: adb` through the existing parser without a public spelling change. `pkg/driver/uiautomator2/driver.go` owns only immediate post-swipe state and the existing selector paths needed to re-read the actual target. Shared `pkg/uiautomator2` element/action/transport context methods are internal plumbing required to make the advertised bounds reach real HTTP operations; the public `UIA2Client` interface was not expanded.

Files changed across the task commits:

```text
CHANGELOG.md
pkg/flow/step.go
pkg/executor/runner_test.go
pkg/driver/uiautomator2/commands.go
pkg/driver/uiautomator2/commands_test.go
pkg/driver/uiautomator2/deterministic_gestures_test.go
pkg/driver/uiautomator2/driver.go
pkg/driver/uiautomator2/driver_test.go
pkg/driver/uiautomator2/notvisible_crash_test.go
pkg/driver/uiautomator2/process.go
pkg/driver/uiautomator2/settle_crash_test.go
pkg/driver/uiautomator2/swipe_geometry_test.go
pkg/driver/uiautomator2/wait_crash_test.go
pkg/uiautomator2/element.go
pkg/uiautomator2/gestures.go
pkg/uiautomator2/request_deadline_test.go
pkg/uiautomator2/transport.go
pkg/uiautomator2/transport_retry_test.go
```

## Live acceptance

No demo source was edited. The supplied APK SHA `c7e4dff77d8f08dd66105d045dede825c80ee137a742e03d8bc2b5979a7df626` was proven stale because its full revealed-node hierarchy exposed only `Remove`, not the literal stock selector `Remove from favorites`; that failed input remains under `software/favorite-1/` and is not counted. A clean external demo worktree at merged commit `1552ae983a27528eff4c1f8145aa075698b47f71` built unchanged Android source; corrected APK SHA `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`. Build command, source status, first missing-SDK failure, retry, and hashes are retained in `demo-build-*` and `demo-build-provenance.txt`.

L51 is unchanged after the clean `4d425170` implementation. On the original owned software AVD (`swiftshader_indirect`, PID `39851`) and GPU AVD (`host`, PID `49159`), the four direction, coordinate, selector, and explicit-ADB forms passed 4/4 on each renderer. Every form retains unique before/after app-only hierarchy and screenshot bytes. Software movements were `-948`, `-939`, `-1184`, and `-1288 px`; GPU movements were `-958`, `-962`, `-1184`, and `-1288 px`. Raw joins are under `software/l51-*`, `software-commit/`, and `gpu/`. Both original devices and owned load processes were cleaned up exactly.

Final affected-path software acceptance used AVD `fix4-2-android-software`, serial `emulator-5580`, explicit `swiftshader_indirect`, emulator PID `70225`, owned load PID `71096`, scoped home `/private/tmp/grantiva-fix4-2.WiwpaS/runner-home`, and session `fix4-2`. Against final clean runner `59184b9` / binary SHA `71d87e…` and corrected APK SHA `5891bf…`, the literal stock favorite flow passed 5/5 under load with all 13 commands passing on every run. Each report retains its own `Favorites With Item` and `Favorites Empty` screenshot bytes, logs, and JSON under `software-fix2-load/favorite-{1..5}/`.

The first final software lifecycle attempt retained the older no-clear-state fixture. `stopApp` passed in 33 ms and exact package checks showed no process, but the following label assertion matched a Nexus Launcher node: package `com.google.android.apps.nexuslauncher`, text `Landmarks`, content description `Predicted app: Landmarks`. That environment false positive is preserved without regrading under `software-fix2-load/stop-bare-1/`, including the complete node, screenshot, hierarchy, empty `pidof`, absent package process, and launcher foreground state.

The accepted L77 flow is the brief's literal `launchApp: {clearState: true}` → bare `stopApp` → `assertNotVisible: "Landmarks"`. Before each run, the owned AVD explicitly foregrounded neutral Settings with `adb shell am start -W -a android.settings.SETTINGS`; `launchApp` then launched Landmarks, and a successful stop returned to Settings instead of the predictive launcher. Software passed 3/3 under load. Every postcondition capture shows an empty exact-package `pidof`, no package process, and `com.android.settings/.homepage.SettingsHomepageActivity` as resumed and focused. Unique before/after hierarchies, screenshots, package state, exact commands, and reports are under `software-fix2-load/stop-bare-neutral-{1..3}/`; the immutable input and hash are in `software-fix2-load/stop-bare-clearstate-input.txt`.

Final GPU acceptance used a separately created AVD `fix4-2-android-gpu`, serial `emulator-5580`, explicit `-gpu host` (gfxstream host / Apple M4 Pro), emulator PID `76116`, and owned load PID `76238`. It used the same final clean runner, corrected APK, scoped home, and session. The stock favorite flow passed 5/5 under load with 13/13 commands each, and the literal neutral-Settings lifecycle flow passed 3/3 under load with 4/4 commands each. All lifecycle postconditions again show no exact-package process and Settings resumed/focused. Unique screenshots, hierarchies, process/foreground state, load snapshots, commands, logs, and reports are under `gpu-fix2-load/`.

Cleanup stopped the exact owned load PIDs, tore down serial `emulator-5580`, removed emulator PIDs `70225` and `76116`, verified serial-specific forwards and session files absent, and deleted both task AVDs. The software deletion's first missing-`JAVA_HOME` failure is preserved; its corrected Java 21 retry succeeded. Final AVD inventory contains only protected `Pixel_8_API_35`, whose config SHA remained `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`. Consolidated accepted summaries, postconditions, artifact hashes, and device cleanup joins are in `findings/evidence/fix4-2/final-live-manifest.txt`. Final host cleanup removed the scoped runner home and registered temporary demo worktree after recording their exact identities; no task temp path remains. Raw proof is `final-host-cleanup.txt` and `final-host-cleanup-followup.txt`. No corrected APK copy is retained after that cleanup (`corrected-apk-retention-check.txt`). Any later Task 8 use must rebuild from clean demo commit `1552ae983a27528eff4c1f8145aa075698b47f71` with fresh source/artifact provenance and must never fall back to stale supplied/root APK SHA `c7e4dff77d8f08dd66105d045dede825c80ee137a742e03d8bc2b5979a7df626`.

## Self-review

- `git diff --check`, final tests, and vet pass; runner source is clean at the pushed head. Scoped fix-round-2 source/spec/quality review approved `59184b9` with no findings, and CI run `38419342152` passed Test, Lint, and Build.
- The hard UIA2 marker is separate from ordinary step contexts: only stable-target operations and named failure captures opt in. Ordinary short step deadlines retain the ten-second request floor and ordinary refusals still run recovery.
- Stable target reads use the hard context at every HTTP-bearing layer. The action is dispatched only after `ctx.Err()` is nil, then gets a distinct hard action context sized for click or long-press duration. Real HTTP tests assert cancellation and zero late clicks.
- Stop verification cannot call the production Android device's context-free shell path: `AndroidDevice` satisfies the narrow internal `ShellContext` interface. Tests block force-stop, process, and foreground commands; assert bounded return, app-specific diagnostics, zero active shell operations, parent cancellation, and retained crash watch.
- Exact-package foreground parsing rejects neighboring packages and irrelevant mentions. Shell-read failure remains unknown rather than proof of stop.
- Raw old failures and completed captures were not overwritten. Review-fix evidence is immutable across rounds: `review-fix-*-v2` for deadline fixes and `review-fix2-*` for ordinary-context preservation. The 13-line lint-only deletion passed focused driver cases and vet before commit.
