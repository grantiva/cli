# CLI slice results: round 3 coverage pass

Binary `~/.grantiva-qa/bin/grantiva` 2.1.0 (CLI main 8f2cff67, bundled runner `grantiva-runner 1.1.28-grantiva.13`, installed
stamp `1.1.28-grantiva.13+android-drivers-2`; runner source grantiva/main fd9d8e8), `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`,
`GRANTIVA_SESSION_ID=cov3-cli`, `GRANTIVA_API_KEY` unset (preamble `findings/evidence/cov3-cli/inputs/env.sh`; helpers
`inputs/lib3.sh`, MCP client `inputs/send.sh`). No devices: device steps use the fake UDID `00000000-0000-0000-0000-0000000000C1`,
serial `emulator-9999` and the names `cov-missing`; landmarks-demo (75acc87) copies have their `simulator:`/`emulator:` lines pointed
at `cov-missing` (and any file `init` wrote is pointed there before any later command) so no command can reach an owner device
(`iPhone 17 Pro`, `iPhone 18 Pro`, `Pixel_8_API_35`) or a campaign device of the iOS/Android slices.
Evidence under `findings/evidence/cov3-cli/<ID>/` (`commands.txt`: cwd, command, exit code and elapsed time; `<label>.out` /
`<label>.err` raw stdout/stderr; `#` lines are setup notes). README, docs, Sources and Tests are read from the 8f2cff67 tree
(`git archive` into scratch, read-only); runner source from the grantiva/runner tarball at fd9d8e8. No `swift build`/`swift test`
was run: unit-test criteria are checked by reading `Tests/` at 8f2cff67, which proves a test exists, not that it passes.
`fail (matrix/brief error — triage)` marks rows whose expected text is stale against a later ruling or fix; the observed
behaviour is in the note.

