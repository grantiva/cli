# SDD ledger — plan: docs/superpowers/plans/2026-10-13-round4-fix-wave.md

## Frozen inputs and rulings

CLI origin/main: `8f2cff676b3c12e951478920fa20e600cdca4e29`; runner grantiva/main: `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. Both fetched and ancestry verified before branch creation. Initial worktrees are clean: runner `fix4/crash-capture`; CLI `fix4/lifecycle-output`.

Round 3 final: 1170 logical / 1329 platform rows; 1281 pass, 22 fail, 20 blocked, 6 n/a. Three separate side findings; all failures covered by 22 open briefs. Independent final integration review approves consolidation. The original candidate and raw captures remain unchanged.

Ruling: Continue authorized PR creation, green-CI squash merges, and campaign pushes without another permission request — approved campaign spec and repeated user authorization govern — incorrect scope would cost reversible branch/review work; release/tagging stays excluded.
Ruling: Create dependent task worktrees from then-current merged main, not all at Task 0 — avoids stale overlapping runner and documentation changes — no acceptance is deferred.
Ruling: Product implementers run device-free baselines and red/green first; reserve device execution with the controller before creating a fix4 device — prevents competing device/load tests — acceptance remains required before completion.

## Preflight interface and consistency scan

| Tasks | Shared file/interface | Finding/ruling |
|---|---|---|
| 1 / 2 / 3 | UIA2 commands, executor flow runner, runner tests, changelog | Execute sequentially from merged main; capture interface precedes lifecycle/status consumers. |
| 3 / 4 | empty device arguments | Separate repos; same trimmed-empty contract, no aliases added. |
| 4 / 5 | CLI build/tests and lifecycle consumers | Separate worktrees; no planned source overlap; merge/retest second branch against main. |
| 4 / 6 | diagnostics/docs consume lifecycle output | Task 6 starts after merged 4 and 5. |
| 5 / 6 | docs/mcp.md and selector/transport contracts | Sequential docs consolidation preserves selector and date requirements. |
| 1–6 / 7 | tested sources into runner bundle | Bundle only merged reviewed heads. |
| 7 / 8 | archive stamps and WDA caches | One version literal, four regenerated runtime caches, fresh cloned upgrade home. |
| 8 / 9 | immutable candidate and full coverage | Smoke gate precedes coverage; failed smoke reopens task. |
| 0 | base/worktree timing | Later branches intentionally delayed until dependencies merge. |
| 1 | cancellable artifact fake vs implementation | Underlying cancellation required; no abandoned timeout goroutines. |
| 2 | gesture table vs shell fallback | Only explicit engine: adb may shell-swipe. |
| 3 | optional reporting vs required control | Production reports/status/exit all required; CLI integration after repack. |
| 4 | parser example vs actual parser | Follow binding Step 3 TargetFlags.validate production path; illustrative TargetOptions spelling is not an instruction to invent a parser. |
| 5 | large response IDs vs completion order | Exactly-once, unconstrained completion order; partial-write integration required. |
| 6 | documentation vs production doctor | L81 must exercise full entry, not helper-only test. |
| 7 | cache regeneration vs installed runtime | Inventory all four; no silently reused cache. |
| 8 | unit home vs upgrade home | Empty unit homes and APFS-cloned device home are separate. |
| 9 | full coverage vs task reruns | Every full matrix row remains; add B4 acceptance rows. |

## Evidence retained

L51: final four-form B3-L51-four-forms-rerun12 and B2-L03-per-step-hierarchy-rerun10 captures remain under findings/evidence/cov3-android; successful movement measurements do not close the held-action implementation finding. L38: B3-L38a sequential rerun4 proves starting/ready semantics while concurrent rerun3 separately proves L80 transport corruption. See reviewed Round 3 report and effective-row table for exact raw joins.

## Brief execution ledger

| Brief | Task | Failing test | Implementation | Device evidence | PR | CI | Merge |
|---|---|---|---|---|---|---|---|
| L51 | 2 | pending | pending | pending | pending | pending | pending |
| L53 | 3 + 4 | pending | pending | pending | pending | pending | pending |
| L61 | 1 | pending | pending | pending | pending | pending | pending |
| L62 | 2 | pending | pending | pending | pending | pending | pending |
| L64 | 1 | pending | pending | pending | pending | pending | pending |
| L65 | 5 | pending | pending | pending | pending | pending | pending |
| L66 | 5 | pending | pending | pending | pending | pending | pending |
| L67 | 6 | pending | pending | pending | pending | pending | pending |
| L68 | 4 | pending | pending | pending | pending | pending | pending |
| L69 | 4 | pending | pending | pending | pending | pending | pending |
| L70 | 6 | pending | pending | pending | pending | pending | pending |
| L71 | 4 | pending | pending | pending | pending | pending | pending |
| L72 | 4 | pending | pending | pending | pending | pending | pending |
| L73 | 4 | pending | pending | pending | pending | pending | pending |
| L74 | 6 | pending | pending | pending | pending | pending | pending |
| L75 | 4 | pending | pending | pending | pending | pending | pending |
| L76 | 4 | pending | pending | pending | pending | pending | pending |
| L77 | 2 | pending | pending | pending | pending | pending | pending |
| L78 | 4 | pending | pending | pending | pending | pending | pending |
| L79 | 3 | pending | pending | pending | pending | pending | pending |
| L80 | 5 | pending | pending | pending | pending | pending | pending |
| L81 | 6 | pending | pending | pending | pending | pending | pending |

Task 0: active — bases and first worktrees prepared; remaining branches created on dependency completion.
