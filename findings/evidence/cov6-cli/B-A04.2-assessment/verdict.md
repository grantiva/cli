# B-A04.2 candidate5 clause assessment

Verdict: **PASS**.

Expected: FlowGenerator emits a settle step (`waitForAnimationToEnd` with a bounded timeout, or the runner's wait-for-idle) after every `tap`/`swipe`/`type` and before each `takeScreenshot`; or the capture waits until two consecutive hierarchy dumps match. Note any added latency in CHANGELOG. (brief A04)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-A04.2-run-1/inspect-corrected.command.json`, `B-A04.2-run-1/inspect.command.json`.
