Every iOS-slice shell: `. env.sh` (exports GRANTIVA, GRANTIVA_RUNNER_HOME, GRANTIVA_SESSION_ID=cov2-ios, unsets GRANTIVA_API_KEY,
sets S/APP/W/E, sources udids.sh and rr.sh). rr.sh: evidence helpers (rr writes commands.txt with uptime/cwd/command/exit/elapsed
and raw out/err; note, res, ka/kastop for keep-alive runs, mcp for the stdio client, mkcfg for project copies). client.py: the
stdio JSON-RPC MCP client from round 1 (_shell steps run in the client's cwd, so later requests cd into the project first).
runflows.sh: one run per flow with a report dir (report.json + runner log kept). gen.py/extract.py: row list and results table.
fg.py (N2-15), blocked_start.py and nohup_hup.py (N2-18): helpers that start grantiva and signal it from Python.
