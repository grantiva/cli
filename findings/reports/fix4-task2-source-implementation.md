# Task 2 implementation report: Android gestures and lifecycle

Status: source implementation and software acceptance complete; final committed-binary software replay and GPU acceptance are in progress.

## Identity

- Runner base: `e5cba28c8ea9fe4ae685b15ffa528bc376b5d3b7`
- Runner head: `4d425170b4522c61952597b802ff5212b97ff418`
- Head tree: `4b4157eb2843a1be421148626641c80c6a9b573e`
- Branch: `fix4/gestures-lifecycle`
- Final scoped runner: `/private/tmp/grantiva-fix4-2.WiwpaS/runner-home/grantiva-runner`
- Final runner SHA-256: `353a3d9ff4d3be2950266c0ab7767f0776e7024dbfa4bf999e8e87892c650727`
- `go version -m` records `vcs.revision=4d425170b4522c61952597b802ff5212b97ff418` and `vcs.modified=false`; raw identity is `findings/evidence/fix4-2/final-binary-identity.txt`.
- QA CLI remained frozen. The task runner and Android driver APKs were installed only in the APFS-cloned scoped home; `findings/evidence/fix4-2/scoped-driver-install.txt` records their hashes.

## RED and GREEN

Focused RED command, run with a newly created empty home assigned to both home variables and `GRANTIVA_API_KEY` unset:

```sh
unit_home=$(mktemp -d /private/tmp/fix4-2-focused-red.XXXXXX) && env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" go test ./pkg/driver/uiautomator2 -run 'Test(SwipeFormsUseHeldActionsUnlessADBIsExplicit|SwipeEngineADBIsParsed|StopAppVerifiesExactPackagePostcondition|StopAppStoppedPackageClearsCrashWatch|PostSwipeTap)' -count=1 -v
```

Observed RED failures were literal: all three non-ADB forms recorded no W3C drags, `SwipeStep.Engine` did not exist, an ineffective force-stop still passed and disarmed the crash watch, and the post-swipe stability fixtures failed before reaching their assertions because the old coordinate path required a device shell. The first required-package RED command was also run:

```sh
go test ./pkg/driver/uiautomator2/... ./pkg/executor/...
```

It exposed expected old shell-routing assertions and test fakes whose intentional stop never changed process state. The original terminal stream was not retained to a file; this limitation is explicit. The failing fixtures were corrected by making legacy ADB controls opt in with `engine: adb`, and by making intentional-stop fakes actually transition to stopped. No production criterion was relaxed.

Focused GREEN commands:

```sh
env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" go test ./pkg/driver/uiautomator2 -run 'Test(ActivityLineHasExactPackage|SwipeFormsUseHeldActionsUnlessADBIsExplicit|SwipeEngineADBIsParsed|StopAppVerifiesExactPackagePostcondition|StopAppStoppedPackageClearsCrashWatch|PostSwipeTap)' -count=1
env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" go test ./pkg/executor -run TestRunnerStopAppFormsResolveApplicationID -count=1
```

Both passed. The final required checks used separate fresh empty homes, assigned both home variables, unset the API key, verified the homes empty before and after, and removed them:

```sh
env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" go test ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/core/...
env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME="$unit_home" MAESTRO_RUNNER_HOME="$unit_home" go vet ./pkg/driver/uiautomator2/... ./pkg/executor/... ./pkg/core/...
```

Results: UIAutomator2 driver `206.951s`, executor cached pass, core `0.656s`, vet exit 0. Raw output and empty-home metadata are `findings/evidence/fix4-2/{full-green.*,vet.*}`.

## Implementation

- `pkg/driver/uiautomator2/commands.go`: direction, start/end percentage or pixel, absolute-coordinate, distance, and element-origin swipes use the shared held W3C drag; only explicit `engine: adb` uses `input swipe`. `stopApp` polls both exact-package process state and exact resumed/focused activity for at most two seconds and fails with the app ID if either remains.
- `pkg/uiautomator2/gestures.go`: distributes the move-duration remainder across pointer moves, preserving the exact requested duration for ordinary and new swipe callers.
- `pkg/driver/uiautomator2/driver.go`: records only a successful swipe and revalidates the immediately following selector tap until two fresh nonzero bounds reads agree. `SetContext` clears that state at flow boundaries. This narrow driver state is required because command dispatch, not the swipe helper, sees the following action.
- `pkg/flow/step.go`: retains the already documented public `engine: adb` YAML value. This is a parser-model addition only; public key spelling and JSON/report structures are unchanged.
- Crash-watch disarming now occurs only after a verified successful stop.
- Tests cover all swipe forms and exact durations, parsed ADB opt-in and its single shell command, moving-to-stable target reads and exact stable center, callback-without-state-change assertion failure, exact-package foreground parsing, ineffective stop behavior, verified stop watch cleanup, and bare/scalar/mapping app-ID resolution.
- `CHANGELOG.md` documents the behavior.

Files changed in the runner commit:

```text
CHANGELOG.md
pkg/driver/uiautomator2/commands.go
pkg/driver/uiautomator2/commands_test.go
pkg/driver/uiautomator2/deterministic_gestures_test.go
pkg/driver/uiautomator2/driver.go
pkg/driver/uiautomator2/driver_test.go
pkg/driver/uiautomator2/notvisible_crash_test.go
pkg/driver/uiautomator2/settle_crash_test.go
pkg/driver/uiautomator2/swipe_geometry_test.go
pkg/driver/uiautomator2/wait_crash_test.go
pkg/executor/runner_test.go
pkg/flow/step.go
pkg/uiautomator2/gestures.go
```

## Live acceptance to date

Software AVD `fix4-2-android-software` ran exclusively on `emulator-5580`, explicit renderer `swiftshader_indirect`, emulator PID `39851`, session `fix4-2`, and the scoped runner home above. One owned load process, PID `40012`, was recorded and removed by exact PID. Host load reached `79.87` during the concurrent iOS replay, so no low-load timing conclusion is claimed.

The original supplied APK SHA `c7e4dff77d8f08dd66105d045dede825c80ee137a742e03d8bc2b5979a7df626` proved stale relative to the required stock selector: its revealed app hierarchy contained only `Remove`, with no text or content description `Remove from favorites`. The complete app-node attributes, screenshot and failed stock report remain in `software/favorite-1/`. Per controller ruling, no selector changed and no demo source was edited. A clean detached task-owned demo worktree at merged commit `1552ae983a27528eff4c1f8145aa075698b47f71` built Android source unchanged from `75acc87`; the corrected APK SHA is `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`. Build command, clean source state and hashes are in `demo-build-provenance.txt`.

Against that corrected APK, the precommit source-equivalent runner binary passed:

- L51 four forms 4/4. Every unique report retains before/after screenshots, active-session raw hierarchy, and app-only JSON. Common-row movement was direction `-963 px`, coordinates `-939 px`, element `-1160 px`, explicit ADB `-1288 px`. The first invalid fixture expected `Landmark 11`; its raw failure showed valid movement only through `Mono Lake`, so the accepted fixture asserts the actually revealed `Mono Lake` without changing the gesture or measuring a stale target.
- Exact stock favorite removal 5/5 with literal `Remove from favorites`.
- Bare stopApp 3/3, plus the ineffective-shell unit case above.

The corresponding raw joins are `findings/evidence/fix4-2/software-corrected/{l51-summary.json,l51-movement.json,favorite-summary.json,stop-bare-summary.json}` and their per-run reports. The final committed binary is repeating these software controls under `software-commit/`; GPU creation and the same complete controls remain pending.

## Self-review

- `git diff --check` passes and the worktree is clean at the committed head.
- Public names, flags, YAML spelling, and report JSON were preserved. Unknown engine strings retain held-drag behavior instead of introducing a new rejection.
- Stable target verification consumes only the immediate successful-swipe state, uses fresh selector dispatch paths (relative, indexed/sized, text, and general), accepts only two identical positive bounds, honors a smaller explicit tap timeout, and clears at flow boundaries.
- Stop verification treats shell-read failure as unknown, never as proof of stop; foreground matching requires an activity component beginning with the exact package plus `/`, excluding neighboring packages and irrelevant occurrences.
- Task 1 cancellable failure-artifact behavior is preserved. Test fake changes make the stop postcondition truthful rather than bypassing it.
- No demo source or shared flow was edited.
