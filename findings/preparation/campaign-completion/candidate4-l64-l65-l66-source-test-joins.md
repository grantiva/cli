# Candidate4 L64/L65/L66 source-test join check

Status: read-only proposed source joins. This report does not grade runtime clauses.

Authority is `findings/evidence/completion-coverage/source-evidence-disposition.json` (SHA-256 `9ba930ea42e8712a1c79ab5dca8e603ec64a9d38547e33d2cde3a95f6fafcfe3`), which accepts the candidate4 exact-tree 2,027-test Swift run and unchanged-runner uncached test result without rerunning them.

## B4-L65.2, iOS and Android: complete product-test join exists

Exact product test:

- `Tests/GrantivaMCPTests/ToolErrorContractTests.swift`
- SHA-256 `a9ddd874284bca44cbbe6054e721ab17b286f529f52aec536bba364012779ba7`
- `ToolErrorContractTests.testScriptArgumentContractsThroughRegistryOnBothPlatforms`

The test loops over `Platform.ios` and `.android`, invokes `grantiva_script` through `ToolRegistry`, and pins all relevant contract fields: missing steps has `isError == true` and exact text `Error: Invalid argument: 'steps' is required.`; wrong type is a distinct exact error; empty steps is non-error; and a disconnected registry checks no-session precedence (`isError == true`, contains `No active runner session`, and does not contain `'steps'`). This is the required product test rather than a smoke-helper assertion.

Accepted execution:

- `findings/evidence/fix5-L86-source/full/stdout.raw.gz`, gzip SHA-256 `3f040fa5fdabf857bfbf2910e1564ce19fcad0136f522186bce318f2e8e040d9`; its result records uncompressed stdout SHA-256 `2b64aa20d49e4fc6ae48cdfe0b3c687c12f1de3842634884e712029039e4aab0`.
- Lines 472–473 of the decompressed log name this exact test and record it passed.
- `findings/evidence/fix5-L86-source/full/result.json`, SHA-256 `52251c6839bbd341af7b1cb6d7f15885abc776d8f2f6874f1df3193d732c1e4e`, records exit 0 for the accepted current-tree full run.

Conclusion: the same exact test completes the source/test obligation for both `B4-L65.2 [ios]` and `B4-L65.2 [android]`. Their separate live behavior remains bound to each platform's candidate4 MCP capture.

## B4-L66.3 iOS: complete product-test join exists

Exact product test:

- `Tests/GrantivaCoreTests/WDAClientTests.swift`
- SHA-256 `70eff3d7b910bd0262a2c52b6c49948543cd149a5db0b18445192b0f4c9566e6`
- `WDAClientTests.testPredicateSelectionUsesActualAttributesAndExcludesApplicationNodes`

This test uses a predicate-aware fake WDA node set, rather than a sequence that returns a stub on the second request. For label, identifier, placeholder and a quoted identifier it asserts the selected match kind, exact clicked element (`winner`), actual predicate attributes in priority order, literal escaping, and exclusion of `XCUIElementTypeApplication`. Adjacent named tests additionally pin identifier and placeholder fallback order, but the predicate-selection test alone addresses the exact L66.3 distinction.

Accepted execution is the same full-run log/result above. Decompressed lines 2777–2778 name this exact test and record it passed.

Conclusion: the current product test completes the source/test obligation for `B4-L66.3`. It does not replace L66's real-demo runtime criteria.

## B4-L64.1 Android: complete deterministic regression join exists

Exact product test:

- Runner source `pkg/driver/uiautomator2/launch_crash_after_draw_test.go`
- SHA-256 `a08ec8f7f22d4564633f968a0385a53d6b14e24ede741bcc2e29568f0b98fd9a`
- `TestLaunchFinalFatalDecision`, including subtests `before-return`, `healthy`, and `after-return`

The fixture arms after the `Displayed` snapshot. In `before-return`, it injects the fatal during the following final `pidof` status read, while that read can still see the crashed process. The assertion requires launch failure with `app_crash`. The healthy control must succeed. The after-return control proves a later crash is watched by the following operation and does not retroactively alter the successful launch result. This exactly exercises the timing boundary required by L64.1.

Accepted unchanged-runner execution:

- Runner source HEAD `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, recorded by `findings/evidence/fix4-7b/runner-build/go-test-uncached-metadata-complete/head.txt` (SHA-256 `38e676bf97c72626cc0b329908825c5caeeb60a1becaaa6e15752a79c63b5398`). Candidate4 identifies the same runner source SHA.
- Exact uncached argv includes `./pkg/driver/uiautomator2/...`: `argv.txt`, SHA-256 `fc30ecda2952d95e366f3500b0064771fab85e164dea190c2632efe0dc7e628b`.
- `stdout.log`, SHA-256 `a5ebd80437ffa135bd0a827e43b77437dce415651bf8a9b1dae006656220cfee`, records `ok github.com/devicelab-dev/maestro-runner/pkg/driver/uiautomator2 207.558s`.
- `result.json`, SHA-256 `9e3f2b84be418eb2cb0237b520c6797496a727981aac527ebc4d6f0fa03615bf`, records exit 0, `-count=1`, and the same source HEAD.

The Go invocation was not verbose, so its output names the package rather than each test. The exact unchanged source contains the named regression, the uncached command includes its package, and the package passed. Under the approved unchanged-runner provenance ruling, this completes the deterministic product-test half of `B4-L64.1`. The real-device crash observations remain separate runtime evidence and are not inferred from this test.

No missing source-test coverage was found for these four requested obligations.
