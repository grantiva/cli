# iOS attempt 103b and Android B3-L48 review

Candidate provenance: Grantiva CLI `8f2cff67`. Runtime evidence is the named current-round evidence below. This is a scoped evidence review, not a device rerun.

## B2-K14 [ios]: PASS

`cov3-ios-attempt103b` covers each runtime branch in the matrix:

- `same-text.stop.out` is exactly `Stopped keep-alive session (pid 82036, 563907E1-703D-4322-AE5F-FC3B06D03143)` and `same-text.stop.exit` is 0.
- `same-json.stop.out` has `status: "stopped"` (not `not_running`), identifies the iOS device and runner, and `same-json.stop.exit` is 0.
- In both same-directory cases, the terminal `passed` ready document is semantically unchanged before/after stop, the two `/tmp/grantiva-sessions/<runner-pid>.*` files present before stop are absent after it, and the row's lease probe changes from `True` to `False`.
- `other-dir.stop.out` is `{"status":"not_running"}`, exit 0. The independently live other-directory session remains alive (`other-control.alive-after-other: True`), its hierarchy succeeds, its ready document and lease remain present, and it is then stopped by its owner.
- With no session, text mode writes `No active session found.` and exits 0; JSON returns `status: "not_running"` and exits 0.
- The semantic source assertions are explicit at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift:331-441`: the live keep-alive release branch, text rendering, JSON result, and no-session note are asserted. The selected release behavior is also stated by the stop command help/source at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/DriverCommand.swift:966-1090`.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt103b/`.

This does not independently regrade IOS-087: attempt103b exercises a `run --keep-alive` session, whereas IOS-087 names a detached `runner start` session.

## B3-L48.1 [android]: PASS

`B3-L48-driver-timeout-rerun3` shows both required verbose subprocess lines:

- `env60-detach/stderr.txt:9` invokes the runner with `--driver-start-timeout 60` and keep-alive; the command exits 0.
- `env60-run/stderr.txt:53,113` invokes and completes the runner with `--driver-start-timeout 60` for the requested flow; the command exits 0.

The scaling rule is asserted at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift:791-798` (`45 -> 120`, `120 -> 270`, 90-second floor), and the implementation is in `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/DriverCommand.swift`. `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md:197-200` documents the variable, runner default 30, and `max(90, 2n+30)` start wait. The Android runner argument is built in `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/AndroidPlatform.swift` and covered by `Tests/GrantivaCoreTests/AndroidPlatformTests.swift`.

## B3-L48.2 [android]: PASS under its explicit fast-success branch

The exact input was exercised in all three named modes:

- Detached start used `--driver-start-timeout 1`, succeeded in 3.402 s, and was stopped cleanly.
- Foreground start used the same argument, exited 1 in 4.621 s, and preserved the runner's precise reason: UIAutomator2 was not ready after 1 s on each of two starts (3.8 s total). The CLI immediately restated that reason and the `GRANTIVA_DRIVER_START_TIMEOUT` remedy. This is far below the otherwise applicable 90-second floor.
- `run` used `--driver-start-timeout 1` and succeeded in 7.532 s.

The criterion expressly says that a mode which starts successfully within the one-second driver limit is recorded and graded by the named semantic test. `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/RunnerLifecycleCommandTests.swift:800-834` asserts that the wait ends as soon as the runner exits and that the runner's last error line is retained in the user-facing failure. Thus the two successful modes are valid conditional outcomes; the failing foreground mode supplies the observable propagation branch.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L48-driver-timeout-rerun3/`.

## B3-L38-a [ios]: PASS by current-round join

The evidence is deliberately split across repeated starts, as the criterion asks for both detached and foreground starts plus dead and ready states:

- Detached timeline: `cov3-ios-attempt104b/timeline.json` polls at about 100 ms. It records absence, then 29 consecutive `starting` observations without a `port`, followed by `ready` with `port`/`wdaPort: 8511` and a live owner. The detached start exits 0.
- Detached starting responses: `cov3-ios-attempt98d/starting-observations.json` polls through absent to a portless `starting` document. In that state, `starting-resource-hierarchy.json` returns JSON-RPC `-32002`, `starting-a11y_tree.json` returns `isError: true`, and `starting-dump.err` prints the same exact WDA-starting/retry message. The complete named-tool set in that capture returns the starting envelope. Its ready hierarchy and dump subsequently succeed.
- Foreground timeline and starting responses: `cov3-ios-attempt47/starting-observations.json` polls at 100 ms from absent to portless `starting`; its hierarchy resource, a11y tree, screenshot, tap, and dump all return the WDA-starting/retry contract. `ready-observation.json` then records a live ready runner. Attempt70c supplies the foreground ready session-document/hierarchy success control.
- Dead owner: attempt104b installs a row-owned dead-pid sidecar. CLI hierarchy and dump both exit 1 with the no-active-session remedy; MCP tree returns `isError: true` and the resource returns `-32002` with the same no-session remedy. These are the required dead-pid semantics, distinct from the starting message.
- The public wording exists under the “A session that is starting” section of `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/docs/mcp.md` and distinguishes the platform-specific WDA state.

The 104b poll itself samples the session document only; the starting MCP/CLI probes come from the separate, exact current-round detached and foreground repetitions above. Together they cover every named observable without treating the dead sidecar as a startup failure.
