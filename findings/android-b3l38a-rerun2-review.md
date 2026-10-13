# Android B3-L38-a detached timeline rerun2 review

Verdict: partial; do not grade the row yet.

The detached timeline itself is strong. It records an absent first sample, then 23 consecutive portless `state: starting` samples and 300 ready samples for the same PID. Across 324 samples the largest interval is 110.77 ms, satisfying the 100 ms polling cadence with bounded scheduler jitter.

At 0.100 seconds, while the retained session document is portless/starting, the harness concurrently submits all required probes. The hierarchy resource returns JSON-RPC `-32002`; `grantiva_a11y_tree` returns an MCP tool result with `isError:true`; and `runner dump-hierarchy` exits 1. All three carry the exact UIAutomator2-starting/retry text and none gives start-session advice. The two MCP responses complete after the session becomes ready, but their preserved submission state and exact starting response correctly show the condition captured by the server when submitted.

The wrapper does not validate the ready half. There is no `ready-resource.json`, `ready-tool.json`, or corresponding successful result in the evidence directory despite 300 ready samples. The prior `starting-session-contracts-rerun4` evidence proves foreground same-server starting-to-ready behavior; K79 realpath-kill proves dead-sidecar CLI/MCP no-session text. Neither proves that this detached MCP server attaches after its own starting transition.

Smallest remaining input: one detached start with one MCP server; retain a starting hierarchy resource and tree-tool response, wait for the same session to become ready, then successfully request the hierarchy resource and tree tool plus immediate runner dump. The cadence proof can remain joined from rerun2. Wrapper exit zero is not a substitute for the missing files.
