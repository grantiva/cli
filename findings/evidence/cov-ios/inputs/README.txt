Environment preamble used by every iOS-slice shell: `. env.sh` (exports GRANTIVA, GRANTIVA_RUNNER_HOME, GRANTIVA_SESSION_ID=cov-ios,
unsets GRANTIVA_API_KEY, sets S/APP/W/E, sources udids.sh and rr.sh). rr.sh defines the evidence helpers (rr, note, res, ka, mcp, mkreq).
client.py is the stdio JSON-RPC MCP client (extended with _shell/_sleep steps). udids.sh holds the final cov-ios-1 UDID of fix round 1
(the main pass used A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF for cov-ios-1).
