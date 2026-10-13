# Task 8 stock-crash invocation review

Scope: `task8-crash-invocation-report.md`, `task8-crash-invocation-review.diff`, the changed crash-loop lines, the retained Task 1 stock harness/report, and the unchanged surrounding Task 8 assertions. No device command, helper, or smoke rerun was performed.

## Verdicts

- **Specification compliance: APPROVED.** The five crash repetitions now use the invocation path required to materialize the stock flow's Android header environment.
- **Code quality: APPROVED.** The correction is limited to command construction and retains the reviewed report/evidence pipeline.
- **Live acceptance: NOT ASSESSED.** A new controller run in a new evidence directory is still required.

## Review

Attempt 4's absence of a fatal is correctly classified as a harness invocation failure. The retained Task 1 report explicitly excludes its direct-runner `crash-1` for the same reason: direct runner execution does not perform the CLI `FlowEnvironment` conversion that passes stock header environment values as Android intent extras. Accepted `stock-4` through `stock-8` use the CLI.

The revised loop constructs the same material argv shape as that accepted path:

`<frozen CLI> run --platform android --device <owned serial> --no-build --verbose --flow <unchanged stock flow> --report-dir <per-run report>`

It runs through the existing bounded `run()` wrapper with the already reviewed environment, project cwd, raw streams, timestamps, load context, expected exit 1, and copied raw report. The final candidate binary was already frozen and validated before this point.

All behavioral assertions remain unchanged: exactly five runs, failed top-level report, a single Landmarks fatal joined to the matching post-clear launch PID, failed `launchApp` with `app_crash`, no successful launch, bracketing clock probes, and the conservative fatal-to-decision interval within two seconds. The stock flow bytes and hash are unchanged. Healthy, L51, favorite, and stopApp direct-runner paths are unaffected because they do not depend on the CLI-only header-environment conversion.

The original failed attempts remain preserved and no acceptance result is inferred from the no-device validation. No new scoped defect was found.
