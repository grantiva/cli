# Android gesture/realpath and iOS attempt97 review

Read-only review on 2026-10-13. Android runtime evidence is from the current `cov3-android` worktree; runner semantics are from exact checkout `fd9d8e8`. iOS evidence is current-round `cov3-ios`.

## Android B3-L32, B3-L33, B3-L59

**All three rows are fully supported.** `B3-L32-L33-L59-gesture-counters-rerun2/summary.json` records no harness failures: ten stock runs, five double-first runs, three relative-selector runs, and three point-only runs all exit 0 and report passed; the empty form exits 1 with `no selector or point specified`.

- L32: every stock report asserts `Taps: 1`, `Double taps: 1`, and still `Taps: 1`; all ten pass. Five double-first reports independently assert the double count. Relative selector plus point passes 3/3. Per-run `maestro-runner.log` records one device-side `cmd input motionevent` command with planned 80 ms gap; `client.log` contains selector lookup where expected and no `double_click` request.
- L33: point-only double tap and long press pass 3/3 with `Double taps: 1` and `Long presses: 1`. Their `client.log` has no gesture-pad lookup before the coordinate gestures. The relative selector variant resolves `id=gesture-pad` then applies the point, 3/3. Empty input produces the required clear error.
- L59: the five double-first runs are 5/5 and the ten stock runs corroborate them. Each corresponding runner log identifies `cmd input motionevent` and the planned 80 ms gap (observed command completion varies about 120–143 ms, which does not reduce the injected 80 ms floor).

Exact runner source supports the mechanism: `pkg/driver/uiautomator2/commands.go:190-253` constructs one shell sequence of DOWN/UP, `sleep 0.080`, DOWN/UP and logs the path; `pkg/driver/uiautomator2/deterministic_gestures_test.go:294-301` asserts it. The fallback pointer sequence and prohibition on `/double_click` are asserted by `pkg/uiautomator2/double_tap_test.go:89-135`. This satisfies L32's “or equivalent” wording and L59's stricter Android-12+ motionevent ruling.

## Android B2-K79, B2-K104, D2-30

**All three Android halves are fully supported by the joined captures.** `B2-K79-K104-D230-realpath-kill-rerun3/assertions.json` proves the `/private/tmp` realpath owner, non-detached keep-alive owner, owner-kill causing runner death, CLI hierarchy/dump rejection, hierarchy rejection under one second, MCP no-session result, and detached control whose CLI hierarchy/dump survive its starter. Its one false assertion, `mcpAttachedAcrossTmpSpelling`, was sampled while the detached runner was still starting and is accurately not treated as a failure.

`B2-K104-realpath-ready-mcp-rerun1/assertions.json` supplies that exact missing ready-state clause: realpath owner, detached shape, hierarchy ready, and MCP attachment across `/tmp` versus `/private/tmp`, all true, followed by successful stop. Thus the ready complement is not inferred from the pre-ready response. Together the captures establish K79's dead-owner filtering and detached-owner survival, K104's canonical path/alias attachment, and D2-30's owner shapes, cross-spelling MCP attachment, cleanup, and detached lifetime.

## iOS N2-05 from attempt97 + retained controls

**N2-05 [ios] is fully supported as a join.** Attempt97 supplies leg (a): after the exact detached runner PID is killed, `stop.json` has `status: stopped`, `alreadyExited: true`, `runnerPid == pid == 69235`, numeric port, and the preserved postconditions show no sidecars. Attempt94 supplies leg (b): `stop.json.sessions` contains both simultaneously live keep-alive sessions, with distinct U1/U2 UDIDs and runner PIDs, numeric ports, and stopped status. Attempt96b supplies leg (c): ordinary detached start/stop with matching numeric `runnerPid`, `pid`, and `port`; its harness verifies cleanup. These artifacts cover the three literal modes rather than treating one stop shape as representative.

Attempt97 does **not** establish B-I15. Its post-kill hierarchy result is a no-active-session outcome after session cleanup. B-I15 requires the separate live-session transport failures (`timedOut` and `cannotConnectToHost`) and their port/remediation messages, plus the not-installed run branch.
