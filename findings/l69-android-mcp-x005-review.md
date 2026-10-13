# L69, Android MCP, and X-005 scoped review

Reviewed against the round-3 matrix and evidence retained at the candidate CLI HEAD `8f2cff676b3c12e951478920fa20e600cdca4e29`. This review made no live or device calls.

## L69: approved

`regression/docs/superpowers/plans/2026-10-13-coverage-issues-round3/L69-starting-runner-json-omits-null-port.md` accurately captures the N3-03 defect and the limitation of the first-foreground harness:

- The expected `port: null` is supported by the N3-03 matrix row and README lines 414–424.
- Attempt 47 proves the shared already-running starting response: the first command ran in the foreground, while the second detached JSON/plain commands observed its starting session. The draft expressly says this does **not** prove that the first command used the matrix's detached form.
- `DriverCommand.swift:161-165` supplies a nil port for a non-ready session, while `RunnerLifecycleDocument.swift:48-52` omits nil unless `nullWhenUnrecorded` is enabled. That source path explains the observed missing key without overstating runtime proof.
- The final acceptance criterion correctly requires a rerun with the detached first-start form on each platform. Thus the current iOS evidence supports defect triage, while platform-complete acceptance remains future verification.

No correction is required to the brief.

## D2-37 [android]: approved

The current pass is supported by `MCP-label-focus-contracts-rerun1/home/`:

- `mcp/type-no-focus.json` is `isError:true` with the exact required `No focused text field: tap a field before typing "x".` message.
- `mcp/script-step2-no-focus.json` is `isError:true`, identifies `Step 2 (type "x")`, repeats the exact focus error, and lists `Step 1: tapped "Landmarks"` under the steps that ran.
- The standalone and scripted requests start from the retained live Home session without a focused text field. No successful type response appears in either failure leg.

This satisfies the Android half independently of the iOS half.

## D2-36 [android]: approved after targeted completion

The original batch established two selector behaviors and retained one invalid fixture probe:

- `home/mcp/tap-text-favorites.json` successfully taps visible text `Favorites`.
- `edit/mcp/tap-placeholder-name.json` successfully taps `Name`, and `type-after-placeholder.json` then types into the selected field.
- `edit/mcp/tap-content-description-heart.json` returns `isError:true` with `Element not found: "heart"`.
- The retained Edit hierarchy contains `Name` but no `heart`/`Heart` value. Therefore this failed request does not establish a product fallback defect: the harness supplied an iOS-oriented literal that is absent from the Android fixture. It also does not satisfy the matrix's required successful Android content-description match.

`D2-36-content-description-rerun1/` supplies the missing valid content-description leg. Its `mcp/tree-before.json` exposes `label`/`name` `Favorite`, `mcp/tap-content-description-favorite.json` successfully returns `Tapped on "Favorite"`, and the batch summary records MCP, stop, and keep-alive exit 0. Joined with the original successful `Favorites` visible-text and `Name` placeholder taps, this satisfies the Android half. Preserve the original failed `heart` probe as a disclosed fixture mismatch rather than evidence against the product.

## X-005: approved

The cross-platform comparison uses current candidate captures:

- Android: `cov3-android/findings/evidence/cov3-android/X005-android-build-json-rerun3/build/stdout.log`; exit 0, product exists, keys are `applicationId`, `duration`, `errors`, `productPath`, `success`, `warnings`.
- iOS: `cov3-ios/findings/evidence/cov3-ios-attempt44/build-json.out`; exit 0, product path exists in the retained build evidence, keys are `destination`, `duration`, `errors`, `productPath`, `scheme`, `success`, `warnings`.
- Shared keys and types match: boolean `success`, numeric `duration`, array `errors`, array `warnings`, and string `productPath`. The only non-shared keys are the documented platform product fields: Android `applicationId`; iOS `scheme` and `destination`.

This satisfies the exact X-005 comparison criterion.

## B3-L55 ready-file input triage

The literal B3-L55.1/.2 input says to stop while the ready file shows a flow `running`, but the exact candidate does not publish a running ready file:

- `RunCommand.run()` prepares (deletes) the path before execution (`/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/RunCommand.swift:279-280`).
- The watcher in `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Runner/RunnerExecution.swift:196-227` writes the ready file only after `RunnerReportIndex.isComplete(expectedFlows:)` is true, using the terminal `index.readyState`.
- Interruption cleanup can instead write terminal `interrupted` (`/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Runner/RunnerExecution.swift:125-133`). There is no source path that publishes a flow-level running ready state.

Therefore attempt 48's absent ready file during an active flow is expected candidate behavior, not evidence of a separate product defect. Attempt 48b's launch-output observation is an appropriate proof that each stop occurred during actual flow execution; its three exit-130/interrupted/cleanup results may support the output clauses. The matrix's literal `r shows a flow running` precondition remains an expectation conflict for Task 6 and should not be silently claimed as observed.
