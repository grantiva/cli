# iOS attempt 27/27b and cross-platform X-002/X-004 review

Scope: retained current-round artifacts only; no device/build commands.

## X-002 — supported cross-platform

Compared:

- iOS: `cov3-ios-attempt10/pass-json.out`, `fail-json.out`
- Android: `cov3-android/output-contracts-exact-rerun1/JSON-pass/stdout.log`, `JSON-fail/stdout.log`

The corresponding documents have identical key sets and types:

- Success top level: `allPassed` boolean, `reportDir` string, `screens` array.
- Failure top level: the same keys plus `error` string.
- The single flow entry on both platforms has `kind`, `name`, `passed`, `screenshots`, and `steps` with matching types.
- Step entries share `action` string, `duration` number, and `status` string; the failed step adds `message` string on both.
- Pass uses `01-browse`; failure uses `02-exact-negative`. Both platform failures name the exact failed `assertVisible ... exact=true` step and the element-not-visible message.
- Each `reportDir` is an absolute path to that invocation's retained report. Platform/worktree path prefixes differ as expected; representation and type match.

This satisfies the complete X-002 cross-platform criterion. Both workers can cite the four exact files above.

## X-004 — still incomplete due nonmatching interrupted inputs/keys

Pass and fail correspond exactly:

- iOS `cov3-ios-attempt27/pass-ephemeral.ready` and Android `X-004/01.out` have identical keys: `finishedAt`, `flows`, `status`; both group and flow statuses are `passed`.
- iOS `cov3-ios-attempt27b/timeout.ready` and Android `X-004/02.out` have identical keys: `finishedAt`, `flows`, `reportDir`, `status`; both group and flow statuses are `failed`.

The interrupted documents do not have the same key set. iOS `cov3-ios-attempt27/interrupted.ready` contains `reportDir` because `interrupt.command.json` proves the command passed `--report-dir`. Android `X-004/03.cmd` did not pass `--report-dir`, and its embedded ready object omits that key. Both use `interrupted` for group and flow, so vocabulary matches, but the binding row also says same JSON keys.

X-004 should remain ungraded until corresponding interrupted invocations use the same report-dir mode (either both omit it or both provide it). No behavior defect is implied; this is an input/evidence mismatch.

## iOS attempt 27/27b grade review

The first attempt's timeout case is invalid evidence and is correctly excluded: `commands.txt` records exit 64, and `timeout.ready` says `--timeout must be at least 30 seconds.` Attempt27b is the valid retry: its frozen command uses `--timeout 30`, exits 1 after 33 seconds total wall time, and writes group/flow `failed` with no `running` state.

- **B-A06.1 iOS half supported:** active SIGINT yields group/flow `interrupted`; valid timeout yields group/flow `failed`; the passing ephemeral ready file omits `reportDir`.
- **B-A06.2 iOS half supported:** `signal-timing.json` sends SIGINT at 12.82 seconds while the long-wait command is active; the owned command exits 130 and the terminal ready file records group/flow `interrupted`. This is the required observable termination result.
- **B-C04.1 iOS half supported:** `pass-report.ready` names the exact retained `pass-report` directory, which contains report JSON, JUnit, logs, flows, assets, and Allure output after exit.

All three matrix rows are platform `both`. These iOS captures support their iOS halves only; they do not close the unsuffixed rows without the corresponding Android runtime evidence.

## Verdict

Close X-002. Keep X-004 open for a matching interrupted ready-file key comparison. Approve the iOS halves of B-A06.1, B-A06.2, and B-C04.1 while preserving attempt27's three-second timeout as invalid/excluded and using attempt27b for the timeout clause.
