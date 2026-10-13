### Spec Compliance

- ❌ CLI source needs one cancellation fix: a protocol-cancelled response can escape the new write queue after cancellation bookkeeping expires (`Sources/GrantivaMCP/ValidatingTransport.swift:168`, `:206`). L65 and selector production changes otherwise match the requested contracts.
- ⚠️ Task acceptance remains pending: durable literal `heart` demo fixture after app/runner restart, final scoped demo review, and iOS cleanup evidence. The report explicitly documents the failed restart; earlier `heart.fill` or initial-install success does not close that gate (`task-5-report.md`, “Binding live results” / “Cleanup”). PR/CI/merge remain controller work.

### Strengths

- Missing `steps` receives the exact required text while wrong-type behavior is preserved (`Sources/GrantivaMCP/Tools/ScriptTools.swift:78`). Registry tests exercise both platforms and preserve no-session precedence (`Tests/GrantivaMCPTests/ToolErrorContractTests.swift:293`). Raw live stdout independently confirms missing/wrong-type/empty-array controls on both platforms and no-session errors (`findings/evidence/fix4-5/ios-final-contracts/stdout.raw:2`, `android-final/stdout.raw:3`, `ios-no-session/stdout.raw:2`, `android-no-session/stdout.raw:2`).
- Selector order now queries actual `identifier`; predicate-based fixtures evaluate real node attributes and verify the winner, priority, escaping, and application exclusion (`Sources/GrantivaCore/WDA/WDAClient.swift:245`, `Tests/GrantivaCoreTests/WDAClientTests.swift:220`). Focused inspection of the cut-off `tapByLabel` function confirms the shared exclusion/escaping and one-retry behavior remain intact (`WDAClient.swift:257`).
- The actor gate holds ownership across partial writes, retains the active write against caller cancellation, and propagates terminal write failure through queued continuations (`Sources/GrantivaMCP/ValidatingTransport.swift:149`, `:159`, `:175`, `:183`). Production already wraps stdio at this boundary (`Sources/GrantivaMCP/MCPServer.swift:22`), so no redundant MCPServer edit or dependency bump is needed.
- Independently parsed both final raw transport captures: all 59 iOS / 56 Android records are valid JSON-RPC; all 20 large IDs and ten small IDs arrive exactly once; each platform has ten resource-updated notifications. Large frames exceed 65,536 bytes (`findings/evidence/fix4-5/ios-final2-transport/stdout.raw`, `android-final/stdout.raw`).
- Final suite evidence shows 278 MCP + 948 Core + 643 CLI + 101 API = 1,970 passing tests; no `warning:`/`error:` log entries. Fresh home is empty before/after, API key absent, exit zero (`findings/evidence/fix4-5/unit/final-full.log:630`, `:2811`, `:5132`, `:5370`; `final-full-environment.json:1`).

### Issues

#### Important (Should Fix)

- **Cancelled queued responses become eligible again after two seconds.** `sendWholeMessage` correctly delays `cancellations.outgoing` until gate acquisition (`Sources/GrantivaMCP/ValidatingTransport.swift:168`), but `forward` unconditionally forgets cancelled IDs after the default 1,000 ms retry schedule plus 1,000 ms grace period (`:206`). If stdout is backpressured for longer, the queued response loses its cancellation marker and is sent when the preceding frame finishes. SDK cancellation only cancels the already-completed handler task, not the outer task waiting to send (`.build/checkouts/swift-sdk/Sources/MCP/Server/Server.swift:791`, `:826`). Preserve the cancellation marker for responses known to be queued until they are dropped/drained; retain bounded cleanup for cancelled handlers that never produce a response. Add a focused regression that holds the first partial frame beyond cancellation expiry, cancels a queued second response, then releases the first and asserts the second is absent and a subsequent uncancelled sender completes. The current protocol cancellation test releases immediately after a 20 ms scheduling delay and cannot catch this (`Tests/GrantivaMCPTests/MCPTransportTests.swift:227`, `:253`).

### Assessment

**Task quality:** Needs fixes.

**Reasoning:** Exact error wording, selector semantics, framing ownership, failure handling, and supplied large-response evidence are sound. Cancellation retention does not yet cover prolonged backpressure; literal demo fixture durability and iOS cleanup are separate unclosed acceptance gates.

**Checks:** Read the supplied diff once, with a second read only to recover tool-truncated middle output. Named outside-diff risks checked: production transport wiring; SDK partial-write/disconnect cancellation behavior; cancellation expiry versus queued responses (tracker plus SDK send/handler ownership); selector function continuation cut off in diff. Parsed retained live stdout and inspected supplied suite/environment evidence; no tests rerun, devices touched, agents spawned, or source mutations performed.
