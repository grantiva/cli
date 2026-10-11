# SDD ledger — plan: docs/superpowers/plans/2026-10-13-round3-fix-wave.md
Spec: docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md (read). Briefs: docs/superpowers/plans/2026-10-12-coverage-issues-round2/L05–L48 + 2026-10-11-coverage-issues/K111.

## Preflight scan
| pair / task | produces vs consumes | finding |
|---|---|---|
| T4 ↔ T5 | both touch MCPServer.swift (T4 cancellation/prefix; T5 starting state) | T5 rebases after T4 merges. OK |
| T5 ↔ T6 | T5 DriverCommand/EmulatorCommand; T6 usage-error shape in the same files (L26-b) | Ruling: T6 owns the shared mutually-exclusive check; T5 keeps its hunks small; later merger rebases. |
| T1 ↔ T2 | both edit pkg/driver/uiautomator2/commands.go (T1 finds/waits; T2 gestures) | different functions; second merger rebases. OK |
| T1 ↔ T2 on pkg/cli | T1 android.go session settings/start timeout; T2 test.go/keepalive.go abort path | different files. OK |
| T4 ↔ T6 | T4 DiffResult.swift (L23 duration null) vs T6 RunnerArtifactCollector | different files. OK |
| T6 K111 vs T6 L25 | both in MP4LastFrameHold.swift | same task. OK |
| T7 after T4–T6; T8 after T1–T2 (runner) and T4–T7 (CLI); T9 after T8; T10 after T9 | sequencing | OK |
| Each task self-consistency | tests named match files named | OK |

Rulings table from the plan adopted verbatim (L15, L24, L26-a, L28, L30, L31, L38-a, L38-b, L41, L05, L07).
Ruling: runner T1–T2 and CLI T4–T6 dispatched in parallel (separate worktrees); T7 after T4–T6 merge; merge order CLI: T4 → T5 → T6 → T7 → T8, each rebasing — cost if wrong: rebases.
Task 0: complete (bases runner grantiva/main 1be68db, CLI origin/main c65fc17; worktrees created; briefs extracted).
Dispatched (opus, parallel): Task 1 runner crash/timing (fix3-crash; BASE 1be68db), Task 2 runner gestures + demo PR (fix3-gestures; 1be68db), Task 4 CLI MCP/ownership (fix3-mcp; BASE c65fc17), Task 5 CLI lifecycle (fix3-lifecycle; c65fc17), Task 6 CLI output/config (fix3-output; c65fc17). Task 7 after 4–6 merge; T8–T10 sequential.
Task 4: implementer DONE_WITH_CONCERNS (8c7ca96, PR #200; L08: default-device refusal + device named in results; capacity ledger per runner home (<home>/simulator-capacity; default home unchanged); L14 via transport-tracked cancellation; concerns: hunks in MCPServer/RunCommand/DiffCommand/DriverCommand + Shell/XcodeBuildRunner/GradleBuildRunner/ProjectResolver/TableOutput/ValidatingTransport/UITools; CLI run prints 'Booting simulator: iPhone 18 Pro' before refusing (RunCommand, Task 6's file — ruling: Task 4 fix round should fix it, it is the same L08 path); L09 keeps the stock Pixel_8_API_35 name in DefaultEmulator + warning). Reviewer dispatched (opus).
Task 4: review (opus) Needs fixes — Important: diff capture --no-build / grantiva_vrt_capture without a session still drive a sole booted user simulator (no provenance check; docs claim coverage); minors: 'Booting simulator' narrated before the refusal, missing CLI-level tests, loose refusal test, L14 fast-fail stub, 2 s cancellation memory, hint wording. L09/L14/L15/L17/L21/L23/L45 compliant. Ruling: close the no-build path (refuse a sole booted non-created device). Fix round 1/5 dispatched.
