# B-C14.3 candidate5 clause assessment

Verdict: **PASS**.

Expected: GrantivaCLITests/RecordCommandTests: `--frames-at a,b` fails parsing with a ValidationError and the injected device's `recordVideo` is never called; an extensionless `--output` is accepted or rejected before `recordVideo`. (brief C14)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-C14.3-run-1/source-inspection.command.json`.
