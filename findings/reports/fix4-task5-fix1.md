# Task 5 review fix 1 — queued cancellation lifetime

Status: DONE — fix committed/pushed, focused GREEN and full final-head suite passed. Independent re-review/CI/merge remain controller-owned.

Worktree `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-mcp-wda`, branch `fix4/mcp-wda`, follow-up base `62088d41` (campaign base `8f2cff676b3c12e951478920fa20e600cdca4e29`). No device actions needed or performed in this follow-up. Earlier live framing captures remain relevant: this change only fixes cancellation bookkeeping while awaiting the existing gate; message ownership, underlying writes, failure shutdown and framing are unchanged.

## Review finding / fix

Independent reviewer correctly identified that `forward`'s cancellation retry/grace cleanup expires after two seconds by default. A completed SDK handler's response queued behind a backpressured frame could outlive that marker and later be emitted.

`CancellationTracker` now explicitly retains IDs for queued responses, including batch members, before `sendWholeMessage` suspends at the gate. Timed cleanup leaves retained IDs alone. Once the gate admits the response, synchronous screening drops cancelled members and releases retained bookkeeping before any underlying write can suspend. The same deferred release runs when task cancellation or terminal transport failure prevents screening. Releasing before the write also avoids clearing bookkeeping for a later request reusing a completed response ID. Handlers that never produce a response have no retained ownership and continue to receive bounded timed cleanup. Retention count entries disappear on release; no timer loop or unowned task was added.

Source anchors: `RequestCancellation.swift:70` retains response IDs; `:85` releases ownership; `:98` skips expiry for owned IDs. `ValidatingTransport.swift:150` retains before suspension, `:167` releases synchronously across every screening exit. Regression anchors: `MCPTransportTests.swift:264` prolonged backpressure, `:494` batch/expiry/reuse cleanup, `:513` unscreened release.

Touched production files: `Sources/GrantivaMCP/RequestCancellation.swift` (controller-approved helper scope), `Sources/GrantivaMCP/ValidatingTransport.swift`. Tests in existing `Tests/GrantivaMCPTests/MCPTransportTests.swift`.

## RED / GREEN evidence

Evidence directory `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/fix4-5/unit/`. Each command used a newly created empty `GRANTIVA_RUNNER_HOME`, `GRANTIVA_SESSION_ID=fix4-5`, and unset `GRANTIVA_API_KEY`. Environment JSON files record homes and final empty inventories.

- Initial RED `swift test --filter testQueuedProtocolCancellationSurvivesExpiryAndReleasesTheNextSender`: one failure, 111 emitted bytes versus expected 74. Initial variant used an empty retry schedule and waited 1.2 seconds beyond its one-second grace (`fix1-red.log`).
- Exact final-regression RED with production default retries: temporarily restored only `ValidatingTransport.swift` from follow-up base, retaining the new unused tracker helpers so additional tests compile; finally restored edited source byte-for-byte. Same filter failed with **111 versus 74 bytes after a 2.2-second blocked frame**, test duration2.613s (`fix1-red-default.log`, `fix1-red-default-environment.json`). Extra37bytes are the cancelled response. This directly reproduces the review finding; the subsequent uncancelled sender completes.
- GREEN `swift test --filter 'MCPTransportTests|MCPCancellationTests'`: **14 transport + 7 cancellation = 21 passed**, zero failures (`fix1-green.log`, `fix1-green-environment.json`). Final regression uses production retries and2.2seconds of blocked output. Existing active-write cancellation, queued task cancellation, immediate protocol cancellation, write failure/waiter release, explicit disconnect, large mixed frames/notifications and SDK cancellation suppression controls remain passing.
- Two new tracker controls cover retained batch member cancellation, cleanup after screening, ID reuse with bounded expiry, and release before screening after sender cancellation/failure. These test bookkeeping lifetime without exposing internal collections.
- Final full `swift test`: **1,973 passed (281 MCP / 948 Core / 643 CLI / 101 API), zero failures, exit0**, no warning/error log entries. Log `fix1-full.log`, environment `fix1-full-environment.json`. Fresh home `/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/fix4-5-fix1-full-ixjts8m8` was empty before and after, API key absent. Tested source is exactly committed final head `a485f7b6`.

Self-review: all gate admission exit paths execute synchronous release; send gate/writer ownership unchanged; batches and numeric/string ID mapping use existing cancellation conventions. `git diff --check` passed.

## Publication

Demo final committed head `19c1aada9c856479f0c29fbd51c029866ae2b3a9` pushed to existing `fix4/stable-tab-identifier` branch / PR4 successfully (`4e3ecfd..19c1aad`). No demo source changes in this follow-up. Final durable fixture and cleanup evidence remains in main task report.

CLI commit `a485f7b6b3cffedc1f64dcc82851fa80e4080ace` created after self-review; clean worktree. Pushed successfully to existing `fix4/mcp-wda` / PR209 (`62088d41..a485f7b6`). No merge performed.
