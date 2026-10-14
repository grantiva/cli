# N2-10 candidate5 clause assessment

Verdict: **PASS**.

Expected: `init` writes the newest iPhone type an installed iOS runtime can run, and warns when a simulator of that name exists that Grantiva did not create (on this host `iPhone 17 Pro` exists: the warning must name it); doctor advice and every MCP schema `simulator` description use the same name or the static text "newest installed iPhone type"; the grep finds only the shared function and help examples; the xcrun lookup carries a 5 s timeout in source (plan N2-10; README config section and "When neither a flag nor `simulator:` names one" paragraph; brief K37)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N2-10-run-1/schemas.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `schemas.stdout`, `schemas.stderr` retained.
- `N2-10-run-1/source.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `source.stdout`, `source.stderr` retained.
