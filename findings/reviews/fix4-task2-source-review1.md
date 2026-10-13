# Spec Compliance

**Source verdict: Needs fixes.** L51 routing/duration and the L77 parser/app-ID integration match the requested behavior. L62 and L77 add useful production checks, but their advertised polling deadlines do not cover all underlying operations. Final committed-binary software/GPU acceptance and cleanup remain separate pending gates; this review does not mark Task 2 complete.

# Strengths

- `pkg/driver/uiautomator2/commands.go:1571–1673` routes direction, start/end, absolute coordinates, distance and selector swipes through the shared held drag; only explicit `engine: adb` selects shell input. `pkg/uiautomator2/gestures.go:180–193` distributes the duration remainder, retaining the exact move duration rather than truncating it to a multiple of20ms. The new375ms regression exercises this distinction (`commands_test.go:3487`).
- `pkg/flow/step.go:257–260` retains the public engine spelling, and `commands_test.go:3536–3560` verifies one shell input command and no W3C action for explicit ADB. Existing selector-held-action coverage remains in `deterministic_gestures_test.go`.
- `pkg/driver/uiautomator2/driver.go:349–366,476–478` connects stabilization to the actual immediately following selector tap. `deterministic_gestures_test.go:512–619` checks three bounds reads for moving→stable→stable, one click at the stable center, and failure of a subsequent not-visible assertion when an app callback does not change row state.
- `pkg/driver/uiautomator2/commands.go:1981–1985` disarms the intentional-stop crash watch only after a successful verified stop. Foreground matching requires an exact package/activity component instead of an arbitrary substring (`:2571–2610`).
- `pkg/executor/runner_test.go:861–904` parses and runs bare/scalar/mapping forms through the real executor, pinning the inherited or explicit application ID. The unchanged executor already injects EffectiveAppID in top-level, nested/hook and subflow paths (`flow_runner.go:507–512,1609–1614,1861–1864`); no behaviorless executor edit is needed.

# Findings

## Critical

- None identified.

## Important

1. **L77 — the two-second stop postcondition can hang indefinitely and ignores cancellation.** `pkg/driver/uiautomator2/commands.go:2543–2567` checks a wall-clock deadline only after synchronous `appProcessState` and `appForegroundState` calls. The latter uses `shellRetry`; the former can issue pidof, package-UID and process-list reads through that same helper. `pkg/driver/uiautomator2/process.go:32–76` calls `device.Shell` without a context, and the actual `AndroidDevice.Shell` reaches unbounded `exec.Cmd.Run` (`pkg/device/android.go:223–224,531–550`). A stalled adb/dumpsys therefore prevents reaching the deadline check and prevents flow cancellation from ending the step. The preceding force-stop call is also context-free. Use one context bounded by the parent/step and stop-verification budget across the shell operation, retries, all process/foreground probes and poll wait; use the existing owned-child `ShellContext` implementation and wait for canceled child completion. Add regressions that block a process probe and a foreground probe until cancellation and assert bounded failure, app-specific diagnostics, no orphaned shell operation, and no crash-watch disarm.

2. **L62 — a slow bounds read can outlive stabilization and still produce a tap.** `pkg/driver/uiautomator2/commands.go:113–163` passes its two-second context only into `findTapTargetWithContext`. `withBounds(elem, info)` subsequently calls `Element.Rect` under the client's broader step context (`driver.go:833–843`; `pkg/uiautomator2/element.go:327–337`), not the stabilization context. For an ordinary tap without an explicit timeout, `Execute` installs the flow context and no two-second request deadline (`driver.go:107–127,343–353`). If the second rect response arrives after the stabilization context expires and equals the first, the new branch sends Click/LongClick and returns success without checking `ctx.Err()`. Some selector helper attribute reads also use the client step context. Carry the stabilization context through every target/attribute/bounds read and reject expired/canceled stabilization before dispatching the action; preserve the action's legitimate duration budget separately. Add a real HTTP-client fixture whose second bounds response stalls past the stabilization limit and prove that the step fails within the bound with zero click requests, plus a parent-cancellation sibling.

## Minor

- None added; the two blocking findings include their missing regression coverage.

# Named Integration Checks

- **Shell polling deadline/cancellation:** followed only the new stop loop's production dependencies through process.go and AndroidDevice.Shell. The blocking path is confirmed by source. `AndroidDevice.ShellContext:229` already supplies cancellation, exact child ownership and synchronous completion; adopting it should preserve the Task1 model rather than introducing detached timeout goroutines.
- **Stable-read deadline and action semantics:** inspected the existing tap path and `withBounds`, context-aware selector lookup entry points, client request context, Element.Rect, and Execute's step deadline. Relative points and long-press handling are retained, but the new local deadline does not reach all operations (finding2).
- **State reset / executor integration:** checked SetContext call sites at `flow_runner.go:72,1287–1291,1377–1381`; they represent flow or nested-flow timeout boundaries. Inspected the existing app-ID injection paths to verify the bare stop form reaches the same production stop implementation.
- **Task1 artifact preservation:** inspected `driver.go:537–590`: failure screenshot/hierarchy retain per-request contexts, and log-tail collection retains `ShellContext`; none is changed by this patch. The two requested fixes should not replace those explicit per-operation contexts with shared mutable context across concurrent artifact collectors.
- **Recorded scope exception:** the parser field, shared gesture-duration helper and driver state are directly necessary for the requested behavior and permitted by the controller. The brief's named `flow_runner.go` and `bare_scroll_test.go` have no hunks; the executor behavior already exists, while shared held-drag regressions reside in the existing commands/deterministic gesture tests. This is a file-inventory qualification, not a request for empty edits.

# Evidence and Limits

- Read the full 1,298-line package once, base `e5cba28c8ea9fe4ae685b15ffa528bc376b5d3b7` → head `4d425170b4522c61952597b802ff5212b97ff418`, with the brief and implementer report. No git mutations, source edits, device actions, new agents or test reruns were performed.
- Verified retained `findings/evidence/fix4-2/full-green.out` and metadata: UIAutomator2 driver 206.951s, executor cached pass, core 0.656s; exit 0, API key unset, both home variables scoped, initially/finally empty home removed afterward. `vet-metadata.txt` records exit 0 with the same home isolation. The retained stderr files are empty.
- The original full-package RED terminal stream is explicitly not retained. The report describes focused semantic RED observations but names no raw focused RED capture, and none was located in the task evidence index. Those observations remain implementer-reported rather than independently verified; the new production assertions themselves are visible in the patch. Do not regenerate historical RED with a repeated suite.
- Software/GPU results against the final committed binary, live 5/5 favorite removal and 3/3 bare-stop controls, final owned cleanup, CI and merge remain the controller's acceptance gates. Earlier stale-APK/invalid-landmark fixture attempts are reported and must not be counted as passing controls. No demo source edit is required by the reviewed source evidence.

# Assessment

**Task quality: Needs fixes.** Gesture transport and duration handling are cohesive, and the tests exercise real parser, executor and HTTP paths. The new lifecycle/stabilization bounds must constrain the actual shell/HTTP operations before this source can be approved.
