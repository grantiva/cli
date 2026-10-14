# N3-15 candidate5 clause assessment

Verdict: **PASS**.

Expected: Where a simulator of the default name exists that Grantiva did not create, doctor says it is not used as the default (`("<default>" (<udid>) was not created by Grantiva, so it is not used as the default)`); exit code unaffected (README doctor paragraph; brief L08)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `N3-15-run-1/doctor-json.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `doctor-json.stdout`, `doctor-json.stderr` retained.
- `N3-15-run-1/doctor.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `doctor.stdout`, `doctor.stderr` retained.
