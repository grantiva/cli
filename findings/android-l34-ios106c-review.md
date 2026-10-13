# Android B3-L34 and iOS attempt106c review

Provenance: Grantiva CLI `8f2cff67`; runner `fd9d8e8`. This is a read-only review of completed current-round captures.

## B3-L34 [android]: PASS

`B3-L34-scroll-distance-rerun1/decoded-posthoc-audit.json` corrects the original harness's wrong log-path lookup by reading each `runs/N/report/maestro-runner.log`. All five exact seed-many/08-scroll runs exit 0 and pass. Every run records 12 measured down movements and 12 measured up movements; run 5 records a thirteenth up movement, demonstrating the top-up path. Every line reports both requested drag pixels and measured content movement with `measured=true`; no runner log contains the fling-style `input swipe` path.

Exact runner semantics are present at `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/driver/uiautomator2/`:

- `bare_scroll_verify_test.go` asserts scrollable-list drag geometry and topping up a short movement;
- `deterministic_gestures_test.go` covers the held-drag `scrollUntilVisible` behavior and termination by `maxScrolls` only when explicitly supplied;
- the production loop has no implicit hard cap of 20 when `maxScrolls` is absent, leaving the step deadline/no-movement rules in control.

The evidence therefore covers five successful down-to-Landmark-70/up-to-Golden-Gate runs, measured held drags, observed top-up, absence of adb fling substitution, and the source-only explicit-engine/default-cap clauses.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L34-scroll-distance-rerun1/`.

## iOS attempt106c

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt106c/`.

### IOS-020: PASS

The row creates and boots UUID `915441E4-1479-4A77-9747-2D30F2BF943F` directly with simctl, then runs successfully on it. `sessions-before-run.json` and `sessions-after-run.json` never contain that UUID, and `created-before-run.json`/`created-after-run.json` are unchanged. Arbitrary session teardown returns an empty array and `manual-after-session-teardown.json` still reports the manual device `Booted`. Thus the prebooted external device takes no session slot and session teardown does not shut it down.

### IOS-122: PASS

Both corrected branches are explicit. The unowned simctl-prebooted device runs with no session ID and creates no session/created record. Conversely, `owned-sessionless.err` refuses the sessionless run against `cov3-ios-26`, names owning session `cov3-ios`, and gives all required remedies; exit is 1.

### IOS-121: PASS

Before targeted teardown, `manual-homes-before-teardown.txt` lists the UUID's runner device home. `manual-udid-teardown.out` reports that exact home under `deviceHomesRemoved` with no failure; `manual-homes-after-teardown.txt` is empty and exit is 0. The later guarded simctl delete is fixture cleanup after the Grantiva-owned home-removal assertion, not a substitute for it.

### IOS-147: PASS

The README name-based ensure example captures the created UDID, and the README-substituted flow run exits 0 with a complete report. The corresponding teardown also exits 0.

### IOS-148: PASS

The `GRANTIVA_SESSION_ID=cov-ios-tmp` ensure/teardown example exits 0. The post-teardown session inventory contains only the pre-existing `cov3-ios` records and no row-created session/device. Cleanup manifests confirm the temporary devices are absent.

### B-I08.1 and B-I08.2: PASS by runtime/source join

Runtime proves the central ownership contract: the manually booted UUID never appears in `simulator sessions` or the created registry, its normal run succeeds without acquiring a named slot, arbitrary session teardown leaves it Booted, and targeted teardown removes only its runner device home. The owned-device sessionless refusal supplies the complementary ownership guard.

Candidate lifecycle source records `bootedByGrantiva`, excludes prebooted external devices from counting ownership, prunes dead sessionless records, and prevents teardown from shutting down devices it did not boot. Existing exact semantic lifecycle tests cover the dead-owner pruning clause. Joined with the observable attempt106c behavior, both I08 criteria are supported; absence of a transient sessionless record for the manual device is the intended no-slot outcome, not missing evidence.

## B2-K15 [android] interim: text stop-policy leg supported; row awaiting JSON complement

`B2-K15-live-teardown-refusal-rerun1/start.json` records a detached runner on emulator-5554, pid 90590. The subsequent text teardown selects the matrix's accepted stop policy: `text.out` says `Stopped runner session (pid 90590) for emulator-5554.` and then `Killed emulator-5554 (cov3-android).` The retained post-state has no runner/session/lease artifacts, and the controller restored the parent-owned emulator afterward. The harness's expectation of refusal was incorrect because stop and refusal are alternatives; this observed behavior is valid evidence, not a product failure.

The existing `json.out` is empty because that later command operated after the text leg had already killed/restored ownership and received a non-owned-device refusal. It is not the required live-session JSON complement. Keep the whole row pending the separately prepared JSON live leg plus the different-serial/`--all` and exact source assertions; do not require the product to demonstrate both stop and refuse policies.
