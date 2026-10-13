# Task 9 execution-key manifest

Status: **FROZEN PREPARATION SHAPE; VALUES/ACTORS ACTIVATE ONLY AFTER THE TASK 8 ZERO GATE AND CANDIDATE FREEZE.** This manifest changes neither the approved matrix nor the criteria index.

## Effective-result keys

The campaign denominator is exactly the approved **1,489 matrix-expanded effective keys**:

| effective-key owner | count | result destination |
|---|---:|---|
| CLI | 431 | `findings/cov4-cli-results.md` |
| iOS platform | 536 | `findings/cov4-ios-results.md` |
| Android platform | 522 | `findings/cov4-android-results.md` |
| total | 1,489 | three files above |

The sole effective key is determined by the matrix slice/platform expansion. Execution actor does not change key ownership, result destination, or denominator.

Six CLI effective keys require an iOS device actor: `CLI-048`, `CLI-049`, `CLI-061`, `CLI-064`, `CLI-066`, and `CLI-083`. The controller assigns their execution to the iOS agent. That agent returns fresh evidence and a proposed verdict to the controller; the controller writes the one effective result under the unchanged CLI key in `findings/cov4-cli-results.md`. The iOS file may contain a non-result routing ledger entry, but no verdict line for these keys. They remain six of the 431 CLI keys and add zero keys to the iOS 536.

## L85 execution keys

`B4-L85.1` and `B4-L85.4` are iOS-platform effective keys executed by the iOS slice on the owned iOS 26.0 primary allocation. `B4-L85.2`, `B4-L85.3`, and `B4-L85.5` are CLI effective keys executed directly by the CLI slice. None is a CLI handoff, shared half, lifecycle delegation, or supplemental iOS 27.0 key. The existing six CLI handoffs and exact 39 supplemental qualifications remain unchanged.

## Supplemental iOS 27.0 execution keys

The exact Round 3 plan/report subset is 39 supplemental executions, separately enforced and excluded from the 1,489 denominator:

`IOS-201 @27.0`, `IOS-202 @27.0`, `IOS-203 @27.0`, `IOS-204 @27.0`, `IOS-205 @27.0`, `IOS-206 @27.0`, `IOS-207 @27.0`, `IOS-208 @27.0`, `IOS-209 @27.0`, `IOS-210 @27.0`, `IOS-211 @27.0`, `IOS-212 @27.0`, `IOS-213 @27.0`, `IOS-214 @27.0`, `IOS-215 @27.0`, `IOS-216 @27.0`, `IOS-217 @27.0`, `IOS-218 @27.0`, `IOS-219 @27.0`, `IOS-220 @27.0`, `IOS-221 @27.0`, `IOS-222 @27.0`, `IOS-223 @27.0`, `IOS-224 @27.0`, `IOS-225 @27.0`, `IOS-226 @27.0`, `IOS-227 @27.0`, `IOS-228 @27.0`, `IOS-229 @27.0`, `IOS-230 @27.0`, `IOS-231 @27.0`, `IOS-232 @27.0`, `IOS-233 @27.0`, `IOS-234 @27.0`, `IOS-235 @27.0`, `IOS-236 @27.0`, `IOS-237 @27.0`, `IOS-238 @27.0`, `IOS-239 @27.0`.

These lines live in `findings/cov4-ios-results.md` and have fresh evidence. Each is a runtime qualification of its parent matrix row, not another effective matrix result. A parent row cannot be `pass` until its iOS 26.0 evidence and required `@27.0` qualification both satisfy the expectation. A failed or blocked runtime qualification makes the parent non-pass. Final accounting reports **1,489 effective matrix results plus 39 supplemental runtime qualifications**, never 1,528 matrix results.

## Lifecycle execution actors

The controller creates the primary `cov4-ios-26`, `cov4-ios-27`, and `cov4-android` allocations and records exact IDs. For a lifecycle row, the controller may reserve a new row-specific name/ID and delegate the exact targeted create, boot, shutdown, cleanup, or delete command to the named slice for the whole row window. That standing row delegation needs no per-command approval. The slice owns command capture and proposed verdict; the effective result still goes to the destination fixed above. The controller performs final campaign cleanup after reservations return.

The following matrix keys/halves are the lifecycle-bearing population and receive row-targeted delegation to their platform slice unless marked blocked by the governing rule:

- iOS: `IOS-001`–`IOS-009`, `IOS-011`–`IOS-020`, `IOS-121`, `IOS-155`, `MCP-049`–`MCP-054`, `N-09`, `B2-K67`, `B2-K68`, `B2-K69`, `B2-K70`, `N2-03`, `S2-02`, `D2-20`, `D2-21`, `B3-L12`, `B3-L21`, `B3-L22`, `B3-L54.1`, `N3-12`, and `N3-14`.
- Android: `AND-001`–`AND-008`, `AND-010`–`AND-018`, `AND-146`, `MCP-057`–`MCP-062`, `B2-K06`, `B2-K15`, `B2-K27`, `B2-K28`, `B2-K29`, `B2-K30`, `B2-K31`, `N2-06`, `N2-16`, `D2-10`, `D2-28`, `D2-29`, `B3-L35`, `B3-L45`, `B3-L46`, and `B3-L54.2`.
- both, separately delegated per half: `X-014`, `X-016`, `B2-K53`, `B2-K106`, `N2-07`, `N3-04`, `N3-05`, and `N3-09`.
- inherited global-operation exception: `AND-012` stays `blocked Global Constraint`; no `--all` delegation is permitted. `IOS-018` is delegated only under its isolated-home/ledger guard. Previously blocked environment rows retain the rules in the execution plan.

The list covers commands whose behavior under test creates, boots, shuts down, cleans, tears down, deletes, or recovers a campaign device, including MCP and regression variants. A row-specific reservation record names the key/half, slice, literal device name/ID, permitted transitions, start/end time, and returned state. It never authorizes another row, another device, a protected target, a global operation, arbitrary forward/process deletion, or owner-device action.
