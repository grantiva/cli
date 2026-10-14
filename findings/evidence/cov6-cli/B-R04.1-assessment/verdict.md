# B-R04.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro in an empty directory: `grantiva_build` and `grantiva_vrt_capture` return `isError: true` with text naming the missing file, for example `No grantiva.yml or grantiva-android.yml in /tmp/r04-empty. Create one with grantiva init.` (the CLI's C18 wording is fine). (brief R04)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B-R04.1-run-1/grantiva_build.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_build.stdout`, `grantiva_build.stderr` retained.
- `B-R04.1-run-1/grantiva_vrt_capture.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `grantiva_vrt_capture.stdout`, `grantiva_vrt_capture.stderr` retained.
