# B3-L38-a Android v1 static review

The v1 detached timeline is partial evidence, not cadence proof.

- `b3l38a-detached-timeline-client-v1.py` samples in its main thread, then
  performs two synchronous MCP RPC waits and a synchronous
  `runner dump-hierarchy`. No 100 ms samples occur while those calls block.
- `sampledEvery100ms: len(samples) >= 2` only proves two samples exist. It does
  not inspect adjacent timestamps, scheduler jitter, or missing intervals.
- A starting-state request can be submitted while starting but answered after
  ready; response content must be graded together with state at submission and
  response, rather than assumed from the first observed state.

The retained foreground, ready, and dead-sidecar evidence remains additive.
The prepared v2 runs a monotonic sampler in its own thread, records target and
actual time plus jitter every 100 ms, submits both MCP requests without waiting
between them, records session state at submission and response, and runs the
CLI dump concurrently. Its cadence assertion is `maxIntervalMs <= 150`, not a
sample-count proxy. A probe that is answered after ready remains recorded as
such and is not reclassified as a starting response.
