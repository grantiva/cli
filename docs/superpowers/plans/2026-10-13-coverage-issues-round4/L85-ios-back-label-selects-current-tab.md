# iOS label tap selects the current tab instead of the same-named back button

Severity: wrong-result
Component: CLI / iOS WDA selector
Owner: Task 5 follow-up; L66 full-selector acceptance reopened
Candidate: CLI 22055ff981ae1ffd5aaae69190d7af180f239162, runner ba9008f4b2cd2c7320a9c46e04faed612b0958a2 (.15), demo 84af7581b75134b0e417b254e4317d565f7b73c6
Status: confirmed independently in candidate 2 bounded smoke; Task 8 failed, Task 9 gated.

## Reproduction and observed result

Navigate Landmarks → Mountains → Mount "Denali", then tap the real Mountains back button. The category hierarchy now contains the Landmarks application root, a button labelled Landmarks with identifier BackButton, and the selected Landmarks tab. `grantiva_tap` with label Landmarks returns success, but the category remains Mountains instead of returning to the root list containing Golden Gate Bridge. A screenshot 54.6 seconds after runner stop confirms the unchanged screen.

Raw evidence: `findings/evidence/round4-smoke-candidate2/04-mcp-ios-attempt3/helper/active/{requests.jsonl,stdout.raw}`, replies 20–21; corresponding invocation failure and successful stop; `04a-back-collision-diagnosis/` screenshot and exact-device capture metadata. Earlier attempts had separately diagnosed helper defects and are not this finding.

## Cause

Frozen `Sources/GrantivaCore/WDA/WDAClient.swift:249-299` excludes application roots but clicks the first result of a broad label predicate. Multiple actionable elements still match; WDA query order is not a navigation priority. The selected tab is the strongest inference for the winner, not an directly observed clicked ID. The runner does not choose the element.

## Acceptance criteria

- In the exact real collision above, semantic label Landmarks selects the navigation BackButton and reaches the root list containing Golden Gate Bridge. Capture the collision hierarchy before the tap, successful reply and resulting hierarchy, plus an independent screenshot/hierarchy afterward.
- Preserve label → identifier → placeholder priority, label match annotation for a preferred back button, application-root exclusion, quoted-label escaping, unknown-selector errors, one-retry launch behavior, and coordinate taps. An exact matching navigation back button wins within the label stage; ordinary labels keep existing behavior when no such back button exists.
- Transport tests must distinguish competing element IDs, including a broad-label fixture with the tab first, and prove the back ID is clicked. Cover no-back fallback, true identifier and placeholder fallbacks, quoted labels, application exclusion, and existing error/retry behavior.
- Preserve the accepted demo: public UIKit tabs, literal heart identifier in selected/unselected states, label/order/symbol/geometry, separate persistent navigation stacks, and switch-away/switch-back retention. Do not rename demo labels, add selector aliases, rewrite hierarchy, use private APIs, or substitute coordinate taps for the semantic back acceptance.
- Run focused and full Swift suites in separate fresh empty runner homes with GRANTIVA_API_KEY unset; independently review source and live proof, pass required CI, merge the reviewed CLI change, and build/freeze a replacement candidate. Runner/demo/archive sources remain unchanged unless new evidence requires changes. Repeat the complete Task 8 smoke and full campaign gate; do not regrade candidate 2.
