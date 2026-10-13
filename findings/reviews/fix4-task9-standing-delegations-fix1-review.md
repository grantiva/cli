# Task 9 standing-delegation fix1 review

2026-10-13. **Approved for conditional plan adoption; not execution activation.** All three original findings are addressed. No blocking new defect was found in this scoped correction delta. This is not an exhaustive new matrix audit or a finding that any current device, port, absence, load, or cleanup guard has passed.

Read the fix1 report, preserved before file, standing-delegation diff, proposed application-build addendum, and the original review against the previously inspected canonical matrix/pass and slice contracts. Only static file reads, diff, and hashes were used. No tests, builds, device/process inventory, network, source execution, source edits, or result/grade changes occurred. This review is the only write.

## Identity checked

| File | SHA256 |
|---|---|
| `task9-standing-delegations-fix1-before.md` | `80098ce013c80a192dcacbee9615d9c746015c47a5419b774b588459be21f5a5` |
| `task9-standing-delegations.md` | `f53ff2459cd36dd0e1215ddf4bf419114ce98873e783ccafc565285d40beb254` |
| `task9-application-build-routing-addendum.md` | `3eda10b3783137c16c674f12e6ce4bc15a394f34260b8eefa5fc63c809aa2018` |

The original controller disposition paragraph is text-identical before/after. The fix is expressed as an addendum, leaving the previously adopted preparation build-routing document as the historical base.

## Original findings

1. **Missing MCP application-build routes — addressed.** The addendum names every key/leg requested by the initial review, including real run/install/launch, iOS xcodebuild-test failures, dynamic config pickup, cancellation of a running compiler, B3-L08.1's positive named-target leg, and N3-04's previously missing run/test legs. Platform ownership, primary targets, isolated scratch outputs, no Android boot during compile-only work, exclusive compiler/cancellation windows, frozen-artifact restoration, exact evidence distinctions and matrix order remain explicit. Existing root-adopted N3-04 build legs are preserved. No generic MCP compile exception is introduced.
2. **IOS-014 refusal misclassification — addressed.** It now has a separate extra3 reservation for successful ensure → build install under the same session, serial compilation, durable-owner evidence and restoration. The addendum explicitly supersedes the old classification without weakening B3-L08.2's refusal-before-preparation contract. No no-build replacement is allowed.
3. **IOS-110/AND-100 missing lifecycle routes — addressed.** Exact extra3/extra2 names, absence, name-only ensure, returned identity/generation capture and owned deletion are now named. The Android stop prerequisite is constrained to the authenticated newly returned target when required for deletion. No type/creation arguments are silently added to the name-only requests, and existing extra-device limits/protected-target exclusions remain.

## No-config and default-guard interpretation

The new conditional wording for MCP-036/MCP-037 and B2-K95 is an execution safety boundary, **not a conditional success criterion**. These matrix rows still require their literal successful no-config build/install/launch. The addendum explicitly preserves exact requests and absent configuration, forbids adding selector/config arguments to force success, requires a non-pass plus root triage on a selection conflict, and disallows substituting a configured positive case. Therefore it does not authorize grading a safe refusal as pass.

If a literal no-config request cannot safely select the allocated device, the actor must preserve the refusal or unexecuted boundary and report the exact conflict. Root must apply the existing canonical verdict rule: an observed refusal contrary to the expected successful behavior remains `fail` (including `fail (matrix/brief error — triage)` where applicable); an explicit inherited guard retains its prescribed blocked result. “Where safely selectable” must not become a new blanket `n/a`, a new pass-by-refusal rule, or silent permission to run against an owner. There is no need to change the literal request in advance or pretend that target selection has already been verified.

B3-L08.1's first/default leg and N3-13 now explicitly retain their starting-state guards, separately from the positive named-target build. N3-12 and existing protected-owner restrictions remain. Expected no-test-action errors in IOS-112/MCP-039 must still come from the real xcodebuild-test path; parser/default refusal cannot satisfy them.

## Remaining activation boundary

Root adoption of the addendum, independent source-window evidence review, the existing independent-coverage ruling, candidate identity checks and concrete actor/key/target reservations remain required. Fresh free-port/absence/ownership and relevant quiet/build/no-boot starting-state proofs are still outstanding operational gates, not static-review findings. The Android primary reset remains the existing narrowly adopted stopped-AVD generation transition after source-window review. No per-command user or root confirmation is needed inside a properly activated bounded reservation.

The preserved Swift full-suite failure and failed full-suite joins remain non-pass. This approval does not reopen source execution, authorize a rerun or repair, or imply a clean campaign gate.
