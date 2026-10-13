# Task 8 smoke-helper fix round 2 static review

Scope: `task-8-harness-fix2-review.diff`, the updated preparation report, current helper sources, the prior remaining findings 1, 2, 10, and 11, and new breakage introduced by fix round 2. The controller's split-proof ruling for L51 and bounded Task 8 lifecycle ruling are authoritative. No device, build, helper, or previously reported static test was run.

## Verdicts

- **Specification compliance: CHANGES REQUIRED.** The four prior findings are addressed, but the new cleanup/final-force ordering cannot execute as written.
- **Code quality: CHANGES REQUIRED.** The new phase design passes a removed Android target into a helper that unconditionally performs live Android validation.
- **Live acceptance: NOT ASSESSED.** Static review grants no live pass.

## Prior finding disposition

1. **Crash timing: ADDRESSED.** `android_runner_smoke.py:45-63` now retains each ADB clock probe's RTT interval, forms the conservative offset hull across both bracketing probes, converts the failed `launchApp` decision into a fatal-to-decision interval, and requires the complete interval to remain within `0...2.0` seconds. Package/PID correlation and the exact failed decision remain intact.

2. **Explicit ADB swipe proof: ADDRESSED under the controller ruling.** `android_runner_smoke.py:78-94` preserves live exact-session movement and absence of W3C `/actions` for `engine: adb`, explicitly records `externalAdbArgvObservedLive:false`, and does not claim interception of the external command. `candidate_identity.py:17-26` binds the runner repository HEAD and hashed uncached Task 7 four-package proof containing the reviewed production exact-one-`input swipe` test. This matches the accepted proof split in `findings/reviews/fix4-task2-live-review.md`; no new live argv criterion is imposed.

10. **Runner source/proof provenance: ADDRESSED.** `candidate_identity.py:17-26,39` verifies the runner checkout HEAD against `runner.sourceSHA`, hashes every named uncached proof component, requires the exact `go test -count=1` four-package invocation at the same HEAD, unset API environment, distinct empty homes before and after, exit zero, exact four successful package lines, and empty stderr. Packaged/upgraded hashes and versions remain checked.

11. **Lifecycle manifest integration: PARTLY ADDRESSED; superseded by the blocker below.** Phase 03 now passes every required frozen binding and the five named non-destructive phases, and asserts `/status == "passed"`. Phase 08 is isolated, last, uses `--allow-destroy-owned-ios`, and asserts both passed acceptance and the recreate-required marker. The argument/status defects from fix round 1 are closed.

## New blocking finding

1. **Final force teardown cannot run after the newly ordered cleanup (`prepare_fix4_lifecycle_smoke`).** Phase `07-cleanup-before-final-force` explicitly removes the owned Android target while preserving iOS. Phase `08-final-force-teardown` then invokes `lifecycle_smoke.py` with both platform bindings. `Smoke.__init__` unconditionally validates both ownership entries through `candidate_identity.validate` and immediately calls `verify_live_targets()` (`lifecycle_smoke.py:70-89`); that method always executes `adb -s <android_serial> emu avd name` and the Android SDK query and requires them to succeed (`:125-131`). Because phase 07 has removed that serial/AVD, construction fails before `force_teardown()` is reached. Make live target verification phase-aware: an isolated force-teardown invocation must validate only the preserved owned iOS identity, while the five non-destructive phases must continue validating both platforms. Do not weaken the ownership manifest or protected-target checks. The Android target's prior owned cleanup evidence remains phase 07's responsibility.

No other new defect was found in the fix-round-2 changes. Candidate-upgrade, docs/output, and cleanup helper implementations remain the separately accepted controller placeholders. After the ordering defect is corrected, actual final-candidate execution and evidence review are still required.
