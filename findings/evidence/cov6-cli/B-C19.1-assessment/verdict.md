# B-C19.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro prints, on stderr, `grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)` and `grantiva.yml:4: unknown key "screen" (did you mean "screens"?)` before the existing error. Warning (not error) keeps old configs working; `doctor` reports the same as a Project warning. (brief C19)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-C19.1-run-1/run.command.json`, `B-C19.1-run-1/doctor.command.json`.
