# Round 4 candidate 2 smoke — FAILED

Task 8 is not complete. Candidate 2 exposes confirmed product finding **L85**, owned by Task 5: semantic iOS label selection can choose the current Landmarks tab instead of the same-named navigation BackButton. L66 full-selector acceptance is reopened. Task 9 remains gated. Candidate 1 and every first-attempt verdict remain unchanged.

## Frozen candidate

- CLI merge `22055ff981ae1ffd5aaae69190d7af180f239162`, version 2.1.0, QA binary SHA256 `33c62e613703ddbd701a178028e099677b900deb003dceb02c74d86214555c37`.
- Runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, version `1.1.28-grantiva.15`, install stamp `1.1.28-grantiva.15+android-drivers-2`, packaged/installed SHA256 `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`.
- Demo merge `84af7581b75134b0e417b254e4317d565f7b73c6`; exact iOS/Android artifacts and build provenance are in the manifest and build-inputs evidence.
- Immutable manifest `findings/evidence/round4-smoke-candidate2/candidate.json`, SHA256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`.
- Package PR214 independent review and CI38459262712 passed before merge. Fresh release build and cloned-home upgrade preserved 8,069 pre-existing cache entries and verified all 800 packaged WDA files. Independent freeze review APPROVED.

## Governing results

All paths below are relative to `findings/evidence/round4-smoke-candidate2/`.

| Phase | Result | Governing evidence |
|---|---|---|
| Candidate build/upgrade/freeze | PASS, independently approved | `01-candidate/`, `candidate.json` |
| Docs/output | PASS: 172 help pages, 16 tests/0 failures, doctor text/JSON and migration notes; independently approved | `06-docs-output-attempt2/` |
| Device provisioning | PASS, exact installed iOS manifest and owned Android identity; independently approved | `provision/` |
| Android runner | PASS: healthy, crash5, gesture4, favorites5, literal stopApp, optional text/json3, required controls, cycle; independently approved | `02-runner-android-attempt2/` |
| Non-force lifecycle | PASS all startup/ready/detach/absent/log/cycle controls; independently approved | `03-lifecycle-attempt2/` |
| Joint L82/L83/L84 forward ownership | PASS four cases, both unrelated controls preserved, exact owned cleanup; independently approved | `03b-joint-forward/` |
| Android MCP | PASS L65 and ten mixed large-response pairs; independently approved | `05-mcp-android/` |
| iOS MCP full selectors | FAIL L85, independently confirmed | `04-mcp-ios-attempt3/`, `04a-back-collision-diagnosis/` |
| iOS MCP remaining transport after selector failure | NOT RUN; no acceptance claimed | Failure stops full helper before transport |
| Final force teardown | PASS invocation0 and helper passed | `07-final-force-teardown/` |
| Physical cleanup | PASS after exact AVD continuation; initial helper failure preserved | `08-final-cleanup/`, `08-final-cleanup-continuation/`, `08-final-cleanup-verification/` |

## Confirmed product failure

Attempt 3 correctly navigated Denali → Mountains and proved the hierarchy contained a Landmarks application root, an actual Landmarks button with identifier BackButton, and a selected Landmarks tab. The semantic Landmarks tap reported success but left Mountains visible. A screenshot captured 54.6 seconds after successful runner stop still shows Mountains. This is not a delayed hierarchy snapshot.

The frozen CLI excludes application roots but clicks the first broad label match. Independent source diagnosis identifies within-label ambiguity; selection of the current tab is the strongest inference because the clicked element ID is not exposed in the MCP result. L85 requires deterministic matching BackButton preference within the label stage, preserving label → identifier → placeholder, escaping, annotations, errors, retry behavior and accepted persistent demo navigation. No coordinate substitution or weakened expectation is permitted.

The narrow follow-up is in isolated branch `fix4/back-button-label-priority`, initially based on `22055ff9`. It requires meaningful red/green and full tests, independent source/live review, CI/merge, a new frozen CLI candidate and complete replacement smoke. No candidate 2 result will be regraded.

## Retained helper failures and limitations

- Initial docs captured only 150 pages because the parser omitted comma-delimited aliases; scoped fix/review and a fresh full attempt captured 172. Original `06-docs-output/` is retained.
- Initial Android stopped because restricted `dumpsys window windows` omitted the focus field. Additive full-window/UIA/PID captures established Settings focus and Landmarks absence. Reviewed full-window correction and isolated fixtures enabled a complete fresh rerun. All twelve first-attempt generated screenshots were preserved.
- Initial lifecycle log command omitted explicit iOS platform in a dual-config project. The corrected full retry passed. A background report-copy exception during retry occurred after complete terminal Android report capture and during teardown; independent review found no acceptance gap. Future helper reuse should stop/join its snapshot thread or verify terminal evidence before tolerating source disappearance.
- Initial iOS MCP stopped on an over-escaped decoded quote expectation. Attempt 2 exposed an incorrect one-level back-navigation assumption. Both received independent diagnosis, scoped fixes and reviews. Attempt 3 then reached the real collision and confirmed L85; it is a product failure, not another fixture exception.

## Cleanup and protected targets

New smoke-owned iOS UUID `553C67C6-7C11-4976-85A0-148C9C8AC278` was shut down and physically deleted. New Android `emulator-5580` / `smoke4-android`, provision PID `21620`, was stopped and its AVD deleted.

The first cleanup helper conservatively refused two simulator-managed processes and legacy AVD config-key assumptions. It did not signal those unknown processes; exact simulator shutdown/delete removed them. The remaining AVD was authenticated by its successful recorded creation, absence from the pre-provision baseline, and exact `.ini` path/path.rel. An explicit Java21 `avdmanager delete avd --name smoke4-android` succeeded. The fresh verification helper passed with no further actions: device IDs/names, owned PIDs, sessions, leases and forwards are absent.

Protected booted iPhone 17 Pro `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and iPhone 18 Pro `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6` metadata remained equal to baseline, excluding only dynamic data/log sizes. Protected Pixel_8_API_35 config SHA256 remains `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`.

Final independent failed-candidate closeout review is pending. No tag or release was created.
