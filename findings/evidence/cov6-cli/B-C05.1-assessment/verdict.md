# B-C05.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro calls the server's own binary (`Bundle.main.executablePath` / `CommandLine.arguments[0]` resolved to an absolute path), and the stub is never invoked. (brief C05)

Fresh candidate5 negative public, docs, MCP, or exact-current-source evidence satisfies this clause without compiler/live action. Evidence: `B-C05.1-run-1/vrt-compare.command.json`.
