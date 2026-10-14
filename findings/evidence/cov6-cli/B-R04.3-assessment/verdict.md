# B-R04.3 candidate5 clause assessment

Verdict: **PASS**.

Expected: With a config that exists but has no `screens:`, `grantiva_vrt_capture` keeps saying `No screens configured in grantiva.yml`. (brief R04)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B-R04.3-run-1/vrt-no-screens.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `vrt-no-screens.stdout`, `vrt-no-screens.stderr` retained.
