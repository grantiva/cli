# Candidate 4 cross-slice proposed join map

Date: 2026-10-13

Status: **proposal for the Android and iOS actors to verify and grade**. This map does not itself change a ledger verdict.

## Basis and limits

- Canonical inventory: `findings/evidence/completion-coverage/required-keys.json` (1,489 keys; iOS 536, Android 522, CLI 431).
- Candidate: immutable completion-candidate4 manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`.
- Source joins: `findings/evidence/completion-coverage/source-evidence-disposition.json` and the approved `findings/reviews/campaign-completion/candidate4-source-evidence-mapping.md`.
- Runtime joins below use only accepted candidate4 smoke packages under `findings/evidence/completion-candidate4/`. They do not transfer candidate3 runtime results or CLI grades.
- A platform actor must verify the cited package identity and exact clause before adopting any full join.

## Proposed complete row joins

| Slice | Key | Candidate4 evidence | Why the row can join |
|---|---|---|---|
| iOS | `B4-L65.1 [ios]` | `04-mcp-ios/helper/acceptance.json` (`L65ActiveExact`) and its retained MCP transcript | Live iOS session returns the agreed complete missing-steps text through ToolRegistry. |
| iOS | `B4-L65.3 [ios]` | `04-mcp-ios/helper/acceptance.json` (`wrongTypeRetained`, `emptyRetained`) and retained transcript | Both separately documented wrong-type and empty-array behaviors were exercised on candidate4. |
| iOS | `B4-L66.1` | `04-mcp-ios/helper/acceptance.json` (`L66SelectorSuccessAndError`) and retained transcript | Real demo capture exercises label, then literal `heart` identifier, then `Name` placeholder in the required order. |
| Android | `B4-L65.1 [android]` | `05-mcp-android/helper/acceptance.json` (`L65ActiveExact`) and its retained MCP transcript | Live Android session returns the agreed complete missing-steps text through ToolRegistry. |
| Android | `B4-L65.3 [android]` | `05-mcp-android/helper/acceptance.json` (`wrongTypeRetained`, `emptyRetained`) and retained transcript | Both separately documented wrong-type and empty-array behaviors were exercised on candidate4. |
| Android | `B4-L77.5` | `02-runner-android/helper/acceptance.json`, check 4 (`L77`) | Candidate4 successful stop followed by not-visible wait is classified as intentional absence, not `app_crash`. |
| Android | `B4-L82.3` | `03b-joint-forward/helper/acceptance.json`, `interrupt`; corroborating lifecycle package `03-lifecycle-recorder-fix1/helper/acceptance.json` | Owned Android capture retains empty baseline, attachment identity/port, exit 130, immediate/delayed exact-forward absence, and absent session/PID observations. |
| Android | `B4-L82.4` | `03b-joint-forward/helper/acceptance.json`, `normal-stop` and `absent-app` | Both controls remove their owned attachment while the unrelated forward is retained. |
| Android | `B4-L83.3` | `03b-joint-forward/helper/acceptance.json` plus `02-runner-android/helper/acceptance.json` and `03-lifecycle-recorder-fix1/helper/acceptance.json` | tcp6790→tcp16790 survives healthy stock, foreground SIGINT, and normal stop; owned forwards/session/PIDs disappear, while the referenced original acceptance controls are present in the accepted candidate4 packages. |
| Android | `B4-L84.3` | `03b-joint-forward/helper/acceptance.json` | The allocated unrelated tcp16791 forward survives the four required endings; retained traces include baseline/control creation and immediate/delayed inventories, with exact owned resources absent. |

## Source-only or runtime partial joins

These entries may satisfy only the named component. They must remain incomplete until the missing component is joined.

| Slice | Key | Component already supported | Still missing for a complete row |
|---|---|---|---|
| iOS + Android | `B4-L65.2 [ios]`, `B4-L65.2 [android]` | Candidate4 MCP packages prove the live exact text, `isError` envelope, and no-session precedence. | The approved source mapping does not assign a current product-test join pinning the complete contract. Do not treat smoke-helper assertions as the required product tests without a separate source-evidence ruling. |
| iOS | `B4-L66.2` | Candidate4 iOS MCP transcript exercises selection success/error and retry behavior. | Exact proof for match annotation, application-element exclusion, and literal escaping across the whole clause. |
| iOS | `B4-L66.3` | Candidate4 live selector ordering and selected attributes are visible in the retained MCP capture. | A current accepted test join that verifies actual WDA attributes and priority rather than a stub. |
| iOS | `B4-L66.4` | Live identifier behavior is proved. | Current source/comment and `docs/mcp.md` contract join, including any retained `name` fallback semantics. |
| iOS | `B4-L66.5` | The candidate4 MCP package supplies the real-demo runtime portion. | Explicit accepted joins for the complete IOS-102, B2-K78, and iOS D2-36 criteria; do not infer all three from this smoke. |
| iOS | `B4-L85.4` | Approved source mapping joins the public tab implementation and literal heart identifier source half. | Owned iOS26 semantic-back plus switch-away/switch-back runtime, including labels/order/symbol/geometry and retained navigation stacks. |
| iOS | `B4-PC.5` | Approved `swift-pc5-launch-report` mapping covers product tests; lifecycle candidate4 evidence supports passed/failed/interrupted report behavior. | Exact missing-report bounded-wait capture with its distinct error, unless an actor locates it in an already accepted candidate4 raw transcript. |
| iOS + Android | `B4-EJ.3 [ios]`, `B4-EJ.3 [android]` | Approved `swift-ej3-paths` source join; lifecycle/runner smoke includes some root/screens/absolute/subdirectory cycle controls. | Each platform still needs a clause-indexed runtime join proving the exact four-hop absolute spelling, separately written relative operands, root/screens/subdirectory chains, and both aliases. The summary acceptances alone do not enumerate every operand. |
| Android | `B4-L64.1` | `02-runner-android` has five fresh fatal-to-decision runtime failures with `app_crash`. | The row specifically requires a deterministic regression placing the fatal event between the status reads and success decision. The accepted source mapping does not assign that regression to this key. |
| Android | `B3-L57` | `02-runner-android` proves five `launchApp` `app_crash` outcomes and fatal-to-decision timing under two seconds. | Explicit retained proof that no Flutter probe ran and permission grants used one `pm grant` shell, plus the exact end-of-step dead-process condition if the actor cannot bind those fields from existing raw. |
| iOS + Android | `B-C11.2 [ios]`, `B-C11.2 [android]` | L65 smoke proves no-session precedence for `grantiva_script` and live re-entry for that tool. | The clause names the full tap/swipe/type/screenshot/a11y/script tool set and lazy attach/re-check behavior. Do not extend the script-only observation to every tool. |

## Explicit non-joins

- No candidate3 runtime verdict is carried forward.
- The approved source disposition joins only source/test clauses. It does not supply either platform half of `B4-EJ.3`, the live half of `B4-L85.4`, or a final full-campaign gate.
- Fresh CLI evidence is useful only where a required key explicitly asks for the same CLI/public observation. It does not satisfy Android or iOS device behavior by analogy.
- Android rows still being corrected or reviewed (including AND021/022/107/108/144 and later rows) are deliberately absent. Their current evidence must be graded by the Android actor first.
