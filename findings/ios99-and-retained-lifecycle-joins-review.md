# iOS attempt99 and retained lifecycle joins review

Read-only review on 2026-10-13 against the binding round-3 matrix.

## Attempt99 simulator MCP lifecycle

- **MCP-049 through MCP-054: pass.** Attempt99 starts with both exact names absent. In the configured directory, ensure creates cov-ios-3 and cov-ios-4 using only `name`, boot returns cov-ios-3's name/UDID/runtime, and delete returns `deleted:true` for both exact devices. In the empty directory, boot reuses cov-ios-3, ensure reuses cov-ios-4, then a later empty-directory ensure recreates cov-ios-4 and delete removes that exact new UDID. Every saved tool call is a result success and the before/after inventories prove the temporary names are absent after the sequence.
- **IOS-110: pass.** The binding row's input is `ensure {name: "cov-ios-3 iPhone 17"}` followed by delete, and its expected result is only-name ensure plus removal. Attempt99 performs that exact argument shape and deletion successfully, with the before/after inventories proving the temporary name is gone. The row heading names the related list/boot/ensure/delete tool family, but neither the input nor expected-result columns add an independent `grantiva_sim_list` criterion; the earlier partial classification incorrectly inferred one from the heading.

## Attempt98b boundary

Attempt98b did not observe the starting-state session because its harness watched the wrong project session-file location. Its seven `ready-*` tool results and resources are valid ready-state controls only. They must not be used as starting-window proof for N-13/B-R05.2; attempt98c is the appropriate corrected input.

## Retained exact joins

- **B2-K90-a [ios]: pass.** Attempt46 `run-screens.out` narrates `Wait 3s` and `Wait 1.5s`; `run-screens.err` contains the timed live and summary lines `✓ Wait 3s (3.0s)` and `✓ Wait 1.5s (1.5s)`, with no evalScript narration. Capture text and JSON preserve the same labels. Exact candidate/runner source assertions already pin labelled wait generation and narration.
- **IOS-057: pass.** Attempt30 launches a real `run --keep-alive`, sends SIGINT to its row-owned process group, exits 0 with the release notice, and preserves an empty original process group, no matching global session files, and deleted device lease lock afterward. The retained process snapshots cover runner/WDA/log-sidecar cleanup; `sawLogStream:false` only means the polling predicate did not catch the process name and does not negate the actual retained `[log]` output or cleanup evidence.
- **B2-K88 [ios]: pass as a joined row.** Attempt70c runs foreground start in plain/quiet/JSON modes, reaches ready, proves concurrent hierarchy, then SIGINTs the exact foreground parent; all three exit 130 with the cleanup notice and session removal. Attempt96b supplies the unchanged detached start, surviving attachment, and stop. Attempt97 supplies a dead-runner stop document (`alreadyExited:true`) and cleanup, while exact candidate `RunnerLifecycleCommandTests.swift:247` asserts the required text `No running runner (pid 1234 had exited); cleaned up its session.` This meets the row's explicit runtime plus semantic-test clauses without claiming attempt97 printed that text in JSON mode.

## Still missing exact current inputs

- **B2-K14 [ios]: partial.** Attempt89g supplies a successful same-directory stop of a live keep-alive session and cleanup; attempt78c/51 supply the no-session JSON control. The retained current set does not establish both text and JSON live-session outcomes, the other-directory non-interference branch, and the exact ready-file terminal-state rule in one auditable join. Those are the smallest remaining inputs.
- **B2-K86-a / IOS-089:** missing the exact current `runner start --detach` owner followed by `run --no-build` refusal. Attempt47 repeats `runner start`; attempt64's refusal owner is a keep-alive run. These are useful controls but not the named trigger.
- **IOS-088:** no allowed current-round stale `.grantiva/session.json` runtime was found. The only exact stale-pid capture is in the quarantined historical import and cannot be reused. Source semantics alone do not replace the explicit start-cleanly runtime input.
