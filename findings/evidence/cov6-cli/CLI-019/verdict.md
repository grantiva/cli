# CLI-019 candidate5 clause assessment

Verdict: **PASS**.

Expected: `Error:` on stderr, exit non-zero; stdout empty except `run --json`, which prints `{"allPassed": false, "screens": [], "error": "..."}` (README:383-386), and `doctor --json`, which exits 1 with the full check array on stdout and nothing on stderr so README:380's jq pipeline works (corrected round 2)

Clause checks: [True, True, True, True, True, True, True, True, True, True]. Evidence commands: `CLI-019/diff-compare.command.json`, `CLI-019/doctor-ios.command.json`, `CLI-019/doctor.command.json`, `CLI-019/run-empty.command.json`, `CLI-019/sim-teardown.command.json`.
