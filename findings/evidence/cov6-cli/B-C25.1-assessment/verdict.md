# B-C25.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro prints `Not logged in; no credentials at ~/.grantiva/auth.json.` and exits 0; `--json` emits `{"success": true, "message": "No stored credentials"}` (or a `removed: false` field). (brief C25)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-C25.1-run-1/logout-text.command.json`, `B-C25.1-run-1/logout-json.command.json`.
