# Candidate4 Android next runner/MCP reuse map

Scope: canonical Android matrix order from `AND-201` through `MCP-082 [android]`. This is read-only execution preparation, not an actor ledger grade.

Fresh inputs considered:

- The first accepted cov5 Android runtime captures through the current core ledger in `.worktrees/cov5-android/findings/evidence/cov5-android/`.
- Accepted candidate4 Android MCP smoke at `findings/evidence/completion-candidate4/05-mcp-android/helper/`.
- Candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`.

## Exact reusable captures

| Key | Fresh evidence | Reusable observation | Missing clause |
|---|---|---|---|
| `AND-093` | `completion-candidate4/05-mcp-android/helper/active/{requests.jsonl,stdout.raw,result.json}` | Repeated candidate4 `tools/list` responses during an Android MCP session; accepted smoke verifies unique response IDs. Actor may bind the retained response after confirming it contains the required same 22 tools. | None if the retained response decodes to exactly 22 names. |
| `AND-095` | Same active MCP capture, request id 6 | `grantiva_tap` with label `Landmarks` executes against the owned Android session and returns a large updated hierarchy response. | None after actor binds request id 6 to its response and confirms the target screen changed. |
| `AND-104` | Accepted MCP smoke active and no-session subprocesses | Every one of the 49 active request IDs and 2 no-session request IDs received one response; acceptance records unique IDs and ten notification cycles. | None for the literal request/response criterion. |
| `AND-105` | `05-mcp-android/helper/{provenance.json,active/command.json,active/result.json}` | MCP subprocess is explicitly bound to platform Android and completes successfully. | None. |
| `AND-236` | cov5 Android `AND-039/env-empty-header.*` | A flow-header environment value (`LANDMARKS_SEED=empty`) reaches the app and produces the asserted empty-state UI. | None for the general header-environment criterion. Preserve the row-local header fixture as the binding. |
| `MCP-018` | Active MCP requests ids 2, 8, 11, 15…47 and matching responses | `grantiva_a11y_tree` repeatedly returns the current Android hierarchy. The accepted large-hierarchy seed makes labels/types/frames inspectable rather than a trivial helper result. | None after actor records one exact decoded response containing labels, element types and frames. |

## Partial joins only

| Keys | Fresh evidence already reusable | Unique observation still required |
|---|---|---|
| `AND-201`–`AND-239`, except `AND-236` | `AND-106`/`AND-043` prove the stock twelve flows remain healthy; `AND-044` proves one Unicode-arrow tap; `AND-035`–`AND-039` prove CLI/header environment transport; `AND-047`/`AND-048` retain normal/failure reports and screenshots. | The feature rows require their own exact flow forms and state assertions: string/text/id selectors, regex/exact/index, points/gestures, append and Unicode typing, visible/not-visible, every swipe form and negative, scrolling, runFlow, waits, clear-state/stop/kill/back, plain-name screenshot, runner permissions, arguments, and launchApp-scoped environment. Stock health or adjacent environment transport cannot replace those literal cases. |
| `AND-094`, `MCP-043`, `MCP-045` | Android session identity and serial are present throughout accepted MCP provenance; core captures identify the Android SDK and configured emulator. | A decoded `grantiva_context` response for the active session (`platform`, `[Emulator]`, SDK) and a no-runner/configured-emulator response for MCP-045. |
| `AND-096` | Active MCP request id 6 covers the tap member and returns an updated hierarchy. | Fresh `grantiva_type` and `grantiva_swipe` action/updated-tree legs. |
| `AND-098` | Active MCP requests ids 13/17/21…49 run `grantiva_script` with a wait step and return final hierarchy; L65 requests separately pin argument handling. | A script that proves ordered Android dp actions, rather than only `wait`. |
| `MCP-026` | Same wait-script calls prove successful script dispatch/final hierarchy; L65 capture proves missing/wrong/empty argument semantics. | Ordered action result (`Taps: 1`, `Last swipe: up`), unfocused-type stop with exact completed-step list, and invalid multi-step script proving nothing ran. |
| `MCP-076 [android]` | Active `resources/read grantiva://hierarchy` requests ids 7, 10, 14…46 return the JSON hierarchy. | Base64 PNG resource half. Do not infer it from `grantiva_a11y_tree`. |
| `MCP-079 [android]` | No-session request id 2 proves `grantiva_script` returns the exact no-session tool-level `isError`, with foreign project/platform session ignored. | Other named session-dependent tools, if the actor's canonical clause requires plural tool coverage; one script call is not a blanket join. |
| `MCP-080 [android]` | Accepted active capture proves attachment to one current session. | Next-call lazy attach from no session and re-attach after session replacement. |
| `MCP-082 [android]` | MCP smoke proves response completeness, correlation/unique IDs, notifications, and large/small response transport under repeated requests. | Explicit proof that subprocesses do not consume stdin. The response-count acceptance alone does not establish that negative process constraint. |

## No reusable complete capture found

The first accepted runtime set contains no complete literal capture for:

- `AND-097`, `AND-099`–`AND-103`;
- `MCP-002`, `MCP-006`, `MCP-010`, `MCP-014`, `MCP-022`, `MCP-030`, `MCP-032`, `MCP-035`, `MCP-037`, `MCP-040`, `MCP-055`–`MCP-062`, `MCP-064`, `MCP-066`, `MCP-069`, `MCP-071`, `MCP-074`, or `MCP-078 [android]`.

Some adjacent evidence covers setup pieces—core build/run success, AVD lifecycle, captures, crash state, or tool-level errors—but not the exact MCP request, schema, path, selector, refusal, or mutation required by these keys. The actor should execute each unique observable case once and join only genuinely identical clauses afterward.

## Standing scope outcomes

- No key in this bounded range is intrinsically N/A under the standing campaign scope.
- No key asks for global teardown/delete-all behavior. Therefore there is no pre-existing global-operation block analogous to AND-110/AND-012.
- Emulator mutation rows `AND-100` and `MCP-057`–`MCP-062` remain executable only against campaign-owned names and under the actor's device reservation. Existing lifecycle captures are useful setup precedent, not current MCP runtime passes.
- Build/run MCP rows remain subject to the actor's compiler/live window. Lack of a current window is an execution dependency, not N/A and not a reusable pass.
