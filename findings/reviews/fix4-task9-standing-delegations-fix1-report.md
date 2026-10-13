# Task 9 standing-delegation correction — round 1

Status: scoped corrections supplied for independent re-review. No execution or activation performed.

Preserved original draft, including root's controller disposition, at `task9-standing-delegations-fix1-before.md` (SHA-256 `80098ce013c80a192dcacbee9615d9c746015c47a5419b774b588459be21f5a5`). Updated `task9-standing-delegations.md` (SHA-256 `f53ff2459cd36dd0e1215ddf4bf419114ce98873e783ccafc565285d40beb254`) and added proposed `task9-application-build-routing-addendum.md` (SHA-256 `3eda10b3783137c16c674f12e6ce4bc15a394f34260b8eefa5fc63c809aa2018`). The earlier adopted durable build-routing document was not edited. Root's original disposition paragraph is preserved verbatim; new additions remain pending root adoption and actual reservation.

## Finding 1: “Application-build allow-list does not cover required MCP application work”

Added exactly the requested keys/legs: IOS-111, AND-101; MCP-029–032; MCP-034–037; IOS-112/MCP-039; MCP-081; B2-K94 and D2-38 both halves; B2-K95; B3-L08.1 positive explicitly named simulator leg; B3-L14.2 both halves; and N3-04 run plus iOS test while preserving root's existing build-leg adoption. Each entry names actor, allocated target, scratch build, install/launch or expected-failure semantics and distinct evidence. Common restrictions cover exclusive serial compilation/cancellation, Android quiet-window exclusion and no-boot inventories, exact frozen-artifact restoration, unchanged source/candidate, and matrix order.

No-config arguments and guarded default refusals remain literal. The proposal does not invent selection arguments or silently target an owner when a no-config request cannot safely select the allocation; such a mismatch remains non-pass/root triage. No broad MCP build exception or earlier generic-build substitution was added.

## Finding 2: “IOS-014 is incorrectly grouped with refusal-only build controls”

Split IOS-014 out of the IOS-011–013 capacity group and gave it its own exact extra3 row reservation. The addendum explicitly corrects the old routing classification without overwriting that historical document: successful ensure → build install uses one unchanged recorded session, a serial scratch-build slot, before/after capacity/session evidence proving one durable owner, and frozen-app restoration. B3-L08.2 remains refusal-before-preparation; IOS-014 cannot be weakened to no-build/refusal.

## Finding 3: “Two explicit MCP lifecycle rows remain outside the standing target table”

Added IOS-110 to the iOS extra3 table, with exactly `cov4-ios-3 iPhone 17`, fresh absence, name-only ensure, captured returned UUID and exact deletion. Added AND-100 to extra2, with exactly `cov4-android-2`, fresh absence, name-only ensure, newly authenticated generation/serial/PID and exact deletion (targeted stop only if required to satisfy stopped-AVD deletion). No extra type/creation parameters are introduced into either name-only call. Existing at-most-two-extra-iOS and generation rules remain.

Explicitly retained N3-13 and B3-L08.1 first/default-leg starting-state guards in the scheduling paragraph. Existing AND-001 reset, IOS-149 appendix, protected targets, no global cleanup, six CLI handoffs and fixed counts are unchanged. Actual activation stays blank.

Verification was static reading, file comparison and hashes only. No test, build, device/process command, network access, source/product change, matrix/grade edit or helper execution occurred.
