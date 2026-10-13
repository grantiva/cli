# iOS 74/75 and Android MCP/N2/D2/cross-platform review

Scoped review against the round-3 matrix and candidate `8f2cff676b3c12e951478920fa20e600cdca4e29`.

## iOS attempt 74

### B2-K68 [ios]: supported

The free controls from attempt 73 have exit 0, `reclaimed:false`, `leaseReleased:false`, no processes, and the exact no-process text. In attempt 74 the row-owned keep-alive reaches passed hold, the lease claim is preserved before SIGKILL, and killing the parent yields exit -9. Force teardown exits 0 and truthfully reports `reclaimed:true`, `leaseReleased:false`, killed WDA xcodebuild and diagnose groups, the live named capacity record retained, versioned device home removed, claimed staging temp directory removed, explicit report directory preserved, and project session absent. This matches K68 including its explicit K79 ruling that the runner exits with its killed parent.

### IOS-016 / IOS-149: runtime behavior is supported, but IOS-016's literal runner-kill wording conflicts with K68

Attempt 74 faithfully executes the README reclaim sequence and supports IOS-149's observable contract: orphaned helpers and staging are reclaimed, the report is preserved, and cleanup completes. It also supplies every observable IOS-016 clause except the phrase “Kills runner”: the runner has already exited with the SIGKILLed parent, as K68's binding acceptance text expressly says is correct, so teardown kills WDA and diagnose rather than the runner.

This is an expectation inconsistency, not a new product defect. IOS-149 can pass under the README/K68 behavior. IOS-016 should be recorded as supported subject to Task 6 correcting “Kills runner” to allow the runner to have exited with its killed parent; its current literal wording is not evidenced and should not be silently claimed.

## iOS attempt 75

### N2-09 [ios]: supported

The no-report browse run exits 0 and writes only its two explicit shots below `.grantiva/run-captures`; exact-negative exits 1 and adds only its failure PNG there. `.grantiva/captures` does not exist, and both approve and compare refuse with “No captures found” rather than listing run shots or ignored files. The explicit-report pass/fail runs exit 0/1, retain their artifacts in their report directories, and leave the prior run-captures path inventory unchanged. This covers the full iOS platform half.

### D2-20 [ios]: fail join is accurate

Attempts 73 and 74 jointly cover correct free-force, killed-keepalive force, and sessionless non-force behavior. Attempt 73's live ready detached leg still omits `runnerSessionStopped` and reports `reclaimed:false`; L73 tracks this product defect. The ledger fail is supported.

## Android

### MCP-069: supported

The runFlow variant and all three advanced swipe forms (from element, between points, duration) return MCP `isError:true` before capture, name the exact unsupported form, and direct the caller to stop the live runner session. Capture inventories remain empty and the owned sessions stop successfully. This satisfies the refusal-before-anything-runs contract.

### N2-11 [android]: supported

One exact detached session captures all five stock screens through `diff capture --no-build --json`; the start and stop documents share PID 8125, and the stop succeeds after both operations. Replacing only the config with the runFlow screen makes capture exit 1 before producing captures, names runFlow, and gives the required `runner stop` remedy. The retained summary confirms the same runner remains alive after both the stock capture and refusal.

### D2-18 [android]: supported

The decoded audit hashes to five exact current AND-050 documents: pass/fail with and without report directory plus pre-flow bad-device failure. Every executed entry has name/kind/passed/steps/screenshots; every step has action/status/duration, the failing step carries its message, only failures carry top-level error, and the pre-flow document has `allPassed:false`, empty screens, and a nonempty error. Relative screenshot paths are present in the run documents. The grade is supported.

## Cross-platform joins

### X-019: supported

The exact current `02-exact-negative` stderr on both platforms has the same failed-step/error structure, selector-not-visible and closest-text diagnostics, and the identical `Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool)` remediation. Platform driver details and timings are permissible differences.

### X-020: supported

The retained live-session context results contain the same Config, device, toolchain, and Runner Session sections and shared session source/app ID/device ID/PID meanings. The documented headings and platform fields differ exactly as expected: Simulator/Xcode/bundle ID versus Emulator/Android SDK/application ID.

### X-015: not supported by the cited exact input

The comparison correctly finds comparable record fields and ISO-8601 timestamps, and `IOS-010` is one of the 20 provenance-eligible pre-import groups. However, the matrix input requires “one Grantiva device each.” The cited iOS `IOS-010/sessions-json.out` contains three active device records, while Android contains one; the audit selects one iOS record without satisfying or disclosing that input condition. X-015 should remain ungraded until an eligible current iOS sessions document with exactly one Grantiva device is joined, or Task 6 explicitly relaxes the input. This is an evidence-input gap, not a product failure.
