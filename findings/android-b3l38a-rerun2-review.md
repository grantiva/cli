# Android B3-L38-a detached timeline rerun2 review

Verdict: partial; do not grade the row yet.

The detached timeline itself is strong. It records an absent first sample, then 23 consecutive portless `state: starting` samples and 300 ready samples for the same PID. Across 324 samples the largest interval is 110.77 ms, satisfying the 100 ms polling cadence with bounded scheduler jitter.

At 0.100 seconds, while the retained session document is portless/starting, the harness concurrently submits all required probes. The hierarchy resource returns JSON-RPC `-32002`; `grantiva_a11y_tree` returns an MCP tool result with `isError:true`; and `runner dump-hierarchy` exits 1. All three carry the exact UIAutomator2-starting/retry text and none gives start-session advice. The two MCP responses complete after the session becomes ready, but their preserved submission state and exact starting response correctly show the condition captured by the server when submitted.

The wrapper does not validate the ready half. There is no `ready-resource.json`, `ready-tool.json`, or corresponding successful result in the evidence directory despite 300 ready samples. The prior `starting-session-contracts-rerun4` evidence proves foreground same-server starting-to-ready behavior; K79 realpath-kill proves dead-sidecar CLI/MCP no-session text. Neither proves that this detached MCP server attaches after its own starting transition.

Smallest remaining input was one detached start with one MCP server; retain a starting hierarchy resource and tree-tool response, wait for the same session to become ready, then successfully request the hierarchy resource and tree tool plus immediate runner dump. Rerun4 now supplies that complement.

## Final joined verdict after rerun4: pass

Rerun4 independently repeats the detached cadence with 22 starting and 13 ready samples, maximum interval 105.56 ms. On one initialized MCP server, starting resource/tool requests retain the exact `-32002`/`isError` UIAutomator2 retry results; after the same PID becomes ready with port 50280, sequential hierarchy resource and tree-tool requests return complete valid trees. Immediate ready `runner dump-hierarchy` exits zero, all five MCP response lines decode independently, `reader-errors.json` is empty, MCP exits zero, and targeted stop succeeds.

Rerun3 is excluded from lifecycle grading and retained as the separate L80/AND3-OBS-02 transport defect: its concurrent large ready responses interleave at byte 65,536. Sequential rerun4 demonstrates the underlying ready attachment without hiding that failure.

The joined foreground evidence in `starting-session-contracts-rerun4` covers the foreground form and public wording. `B2-K79-K104-D230-realpath-kill-rerun3` covers the dead-sidecar CLI and MCP no-session outcome. Exact lifecycle tests cover early spawned-runner exit and shared state semantics. Together these inputs satisfy the full Android row.
