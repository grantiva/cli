# B-A02.3 candidate5 clause assessment

Verdict: **PASS**.

Expected: Runner test: parsing `swipe: {direction: LEFT, from: X}` yields a non-empty selector; a driver test with a fake page source asserts the swipe start point is inside X's bounds. GrantivaCoreTests: if the CLI pre-validates flows, a MaestroFlowParser test that `from:` is kept, not discarded. (brief A02)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-A02.3-run-1/source-inspection.command.json`.
