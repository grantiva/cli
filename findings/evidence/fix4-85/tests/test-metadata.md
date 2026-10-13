# Task 8 back-priority test metadata

Source worktree: `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-back-priority`

Base: `22055ff981ae1ffd5aaae69190d7af180f239162`

Implementation test commit: `bccc535ef91b24bd4147aef7437bae0866988b8c`

Final HEAD: `6cad3f2b4081f0862cd0e93140eda11c2816b9ba`. Its only change from the implementation test commit is the public `LabelMatch` documentation correction requested by independent source review.

All commands ran with `GRANTIVA_API_KEY` unset. Each green command used a distinct, initially absent runner-home pair.

## Meaningful RED

Exact argv:

`env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME=/tmp/grantiva-task8-red3-runner-home MAESTRO_RUNNER_HOME=/tmp/grantiva-task8-red3-maestro-home swift test --filter WDAClientTests/testTapByLabelPrefersANavigationBackButtonOverACompetingLabelMatch`

Source: base production source plus only the new competing-ID test. Start: 2026-10-13 13:42:52 -0700. End: 2026-10-13 13:42:53 -0700. Exit: 1. The fixture returned `selected-tab` before `navigation-back`; current source clicked `selected-tab`. See `red-observed-excerpt.txt` for the verbatim retained assertion output and its capture limitation.

## Focused green

Exact argv:

`/usr/bin/script -q .../task8-back-priority-tests/focused-green.raw env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME=/tmp/grantiva-task8-head-focused-runner-home MAESTRO_RUNNER_HOME=/tmp/grantiva-task8-head-focused-maestro-home swift test --filter WDAClientTests`

Source: `bccc535ef91b24bd4147aef7437bae0866988b8c`. Start: 2026-10-13 13:47:41 -0700. End: 2026-10-13 13:47:42 -0700. Exit: 0. Total: 28 tests, 0 failures. Both homes remained absent/empty.

## Full green and preserved transient

The first byte-identical precommit full run passed. The first exact-commit raw run, `full-green.raw`, exited 1 because unchanged `SimulatorManagerTests.testBootWaitingOnATwinsBootIssuesNoSecondBoot` observed `nil` instead of `Optional(true)`. That unrelated timing failure is retained verbatim and was not regraded.

Retry exact argv:

`/usr/bin/script -q .../task8-back-priority-tests/full-green-retry.raw env -u GRANTIVA_API_KEY GRANTIVA_RUNNER_HOME=/tmp/grantiva-task8-head-full-retry-runner-home MAESTRO_RUNNER_HOME=/tmp/grantiva-task8-head-full-retry-maestro-home swift test`

Source: `bccc535ef91b24bd4147aef7437bae0866988b8c`. Start: 2026-10-13 13:51:22 -0700. End: 2026-10-13 13:54:39 -0700. Exit: 0. Totals: MCP 281, Core 975, CLI 667, API 101; 2,024 tests total, 0 failures. Both retry homes remained absent/empty.

Final hashes after the comment-only commit:

- `WDAClient.swift`: `1fb27109163a9934d1f824d76f5b285acd28a8a9ead3c00b33c604d8b6abecb6`
- `UITools.swift`: `3d92763def62d1980c3403931128ece75303b1ff1672f3d3e4036aecec6456ec`
- `WDAClientTests.swift`: `70eff3d7b910bd0262a2c52b6c49948543cd149a5db0b18445192b0f4c9566e6`
