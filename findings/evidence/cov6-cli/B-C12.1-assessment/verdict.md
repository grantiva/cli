# B-C12.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro: `doctor` in both/ exits non-zero with "Found both ... Pass --platform ios\|android or set GRANTIVA_PLATFORM." (or reports the second platform as advice, not Required); both `windows` cases fail with the `run` message; both `init` flag cases fail naming the flag, and write no file. (brief C12)

Fresh candidate5 negative public, docs, MCP, or exact-current-source evidence satisfies this clause without compiler/live action. Evidence: `B-C12.1-run-1/doctor-both.command.json`, `B-C12.1-run-1/run-env-windows.command.json`, `B-C12.1-run-1/init-ios-appid.command.json`, `B-C12.1-run-1/init-android-scheme.command.json`, `B-C12.1-run-1/doctor-env-windows.command.json`.
