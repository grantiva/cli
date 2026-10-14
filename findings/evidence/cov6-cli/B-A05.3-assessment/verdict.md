# B-A05.3 candidate5 clause assessment

Verdict: **PASS**.

Expected: GrantivaCLITests/RecordCommandTests: a fixture mp4 with one frame at 0 and requested duration 2 s returns a frame for 1000 ms instead of throwing; a test that `requestedMilliseconds` beyond the requested duration still throws. (brief A05)

Fresh candidate5 docs/public behavior or exact current-source inspection evidence satisfies the named clause; source-only evidence is used only for a source-only key. Evidence: `B-A05.3-run-1/source-inspection.command.json`.
