# Task 9 standing-delegation spec and quality review

2026-10-13. Independent bounded static review. **Changes requested for full-slice plan readiness.** The ownership and activation model is sound, but the strict allow-lists omit literal matrix work and one build classification contradicts the matrix. These are routing gaps, not authorization to expand scope while executing. Unaffected, explicitly covered windows may be activated by root after the real guards and source-window review; this review does not activate anything.

Reviewed: canonical `task9-standing-delegations.md`, including its final controller disposition; `findings/preparation/round4-coverage/task9-application-build-routing.md`; canonical round-4 coverage matrix/pass; preparation execution-key manifest and CLI/iOS/Android briefs. No device/build/test/network command, source edit, result edit, grade assignment, or fresh runtime verification occurred. This review file is the only write.

## Actionable findings

### 1. Application-build allow-list does not cover required MCP application work

**Priority: high; resolve before dispatching the affected keys.** Standing delegations line 70 permits app compilation only for listed build-routing keys. Build routing line 54 likewise says “For only the keys listed above.” The final appendix adds only `N3-04`'s `grantiva_build` legs. The matrix requires additional actual application build invocations that are absent from that allow-list:

| Missing key(s) | Required routing |
|---|---|
| `IOS-111`, `AND-101` | MCP build and run; scratch build, owned install/launch, restoration. |
| `MCP-029`–`MCP-032` | Successful MCP build, with/without configuration and literal argument controls. |
| `MCP-034`–`MCP-037` | MCP run that builds, installs and launches, including no-config argument controls. |
| `IOS-112`, `MCP-039` | Invoke the real xcodebuild test path and retain its expected no-test-action failure; a pre-build parser refusal is not equivalent. |
| `MCP-081` | Start server before creating scratch configuration, then build using the newly read config. |
| `B2-K94`, `D2-38` (both halves) | Build/run product and summary contracts, plus Android build no-boot inventory. |
| `B2-K95` | iOS no-config run builds, installs and launches; retain the literal bundle-ID controls. |
| `B3-L08.1`, positive explicitly named simulator leg only | Build on the allocated simulator after the separately guarded default refusal. No owner/default-device permission. |
| `B3-L14.2` (both halves) | A real running scratch application build cancelled after two seconds, with compiler-process disappearance and transport reuse checks; requires serialized build/cancellation window. |
| `N3-04` run legs and iOS test leg | Appendix currently adds build only; run builds/installs/launches, and iOS test invokes xcodebuild. |

Evidence: matrix lines 822–823, 841, 879–889, 931, 1354–1355, 1464, 1493, 1501, 1571. This list deliberately excludes device-free missing-config/platform/default-refusal controls that do not require a real application build.

**Required correction:** add these exact keys/legs with actor, target, scratch-build permission, install/launch or expected-failure semantics, quiet-window interaction, and frozen-artifact restoration. Retain the existing Android no-boot proof and no new flags. Permit compatible evidence joins only when literal clauses match; do not jump ID order or substitute an earlier generic successful build for cancellation/config-pickup/no-config controls. No blanket “all MCP” or arbitrary app-build delegation is needed.

### 2. IOS-014 is incorrectly grouped with refusal-only build controls

**Priority: high; resolve before IOS-014.** Build-routing line 25 groups `IOS-014` with `B3-L08.2` and says their “precondition/refusal semantics” must not become an unnecessary build. Matrix line 362 instead requires `simulator ensure`, then `build install`, using the same session across commands and proving one durable owner. It is not a default-device refusal case. The standing lifecycle table includes IOS-014 but supplies no explicit successful scratch app-build exception.

**Required correction:** distinguish IOS-014's successful same-session build/install from B3-L08.2's refusal-before-preparation. Authorize only its literal build/install on the reserved owned target, with a serial build slot, before/after capacity/session evidence and frozen-app restoration. Preserve the same session across the commands. Do not turn it into a no-build/default-refusal test to fit the existing list.

### 3. Two explicit MCP lifecycle rows remain outside the standing target table

**Priority: medium; resolve before those keys, or they must pause for root.** Matrix `IOS-110` (line 821) requires name-only MCP ensure followed by delete of extra3. `AND-100` (line 840) requires name-only MCP ensure followed by delete of extra2. Neither is in the preparation lifecycle list nor the proposed standing table. The IOS-149 appendix fixes a similar omission, but does not cover these rows. The current unknown-key pause boundary is safe; it does not meet the intended readiness for complete slice execution without another routing clarification.

**Required correction:** add exactly IOS-110 for literal `cov4-ios-3 iPhone 17` under the existing extra3 name-slot rules, and AND-100 for `cov4-android-2` under the existing extra2 generation rules. Capture absence/create/name-only behavior and exact owned deletion; do not reuse an arbitrary primary or add type parameters to the name-only controls. Preserve the at-most-two-extra-iOS and generation/identity rules.

## Accepted parts and activation conditions

- Root's appendix settles IOS-149, selects the one-time stopped primary Android delete/recreate for AND-001 after source-window review, and adds the precise N3-04 build legs. These decisions are narrow and preserve first provisioning/shutdown evidence. They do not assert fresh absence/free ports or authorize deletion of a still-running generation.
- Reservation fields are sufficient to distinguish literal names, UUID/serial generations, row-owned processes, sessions, and transitions. The proposed 5584/5586 ports are explicitly unverified. Product-selected serial binding remains conditional on live AVD/process authentication; PID 82484 is historical, never a live target.
- Protected devices, unknown state, global cleanup, arbitrary forward removal and pattern signals remain excluded. Exact session membership before session teardown, isolated IOS-018 ledger guarding, immutable-file cleanup, primary restoration, and returned-state records are appropriate.
- One root activation per bounded row/group permits all listed transitions without per-command prompts. The draft safely pauses a materially different target or ownership mismatch. This model needs no recurring user confirmation.
- Source tests remain controller-owned. Slice app-build exceptions never permit CLI/runner rebuild, repack, source fixes, or replacement of candidate artifacts. Preserve the full Swift failure and failed full-suite joins independently of later device results.
- Standing delegation's explicit matrix-order restriction governs build routing's “group build-only commands first”: group only adjacent ready keys or explicitly compatible evidence, not later rows brought forward for convenience.
- CLI result ownership stays 431, iOS 536 plus exactly 39 supplemental runtime qualifications, Android 522; the six CLI handoffs remain single CLI results. No expansion or alternate result writer is introduced.
- Canonical guards still apply to `N3-13` and `B3-L08.1`'s first/default leg even though the standing no-booted bullet mentions only some guarded keys. Root must preserve their literal empty/pre-boot preconditions and owner block when scheduling; this document supplies no permission to shut down an owner or silently waive a precondition.

After the three routing corrections, the plan can receive static approval for conditional use. Actual activation still requires independently reviewed source-window evidence, the existing independent-coverage ruling despite failed Swift, candidate recheck, exact row reservation, real protected/owned inventories, available resources, and the relevant starting-state/absence proof. No current port availability, device absence, compiler isolation, or cleanup state was verified in this review.
