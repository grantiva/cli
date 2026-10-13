# Android B3-L38-b rerun4 review

Verdict: pass.

All three cycles establish a row-owned keep-alive run, query its UIAutomator2 server through a row-owned `tcp:0 → tcp:6790` forward, and retain the old session ID. After SIGKILL of the exact Grantiva parent and death of its runner child, that same server still reports the old session. The harness removes only its own diagnostic forward before starting the replacement.

Each verbose detached start returns zero with a terminal ready record. Its recorded UIAutomator2 port answers `/wd/hub/sessions` with a new ID different from the orphan: `ada1… → 7bdd…`, `153b… → 9f58…`, and `0b8c… → 10d8…`. An immediate `runner dump-hierarchy` and targeted stop both exit zero in all three cycles.

The three verbose start transcripts contain normal runner spawn and row-owned adb-forward operations and contain none of `force-stop`, `kill -9`, `pkill`, or `killall`. Exact-head `RunnerLifecycleCommandTests.swift:747+` covers the old/new-session contract, no server clearing, early spawned-runner exit, and shared foreground behavior. This supplies the source-only clauses that are not safely induced in the three detached runtime cycles.
