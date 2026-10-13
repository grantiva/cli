# Task 8 candidate 2 — iOS MCP back-label live diagnosis

## Verdict

**Classification: product selector collision; candidate 2 L66 acceptance remains failed.** Attempt 3 successfully constructed the intended live state, but `grantiva_tap(label: "Landmarks")` left the app on the Mountains category. The additive screenshot taken about 55 seconds after the failed invocation, after the runner had stopped, still shows Mountains. That rules out an immediate hierarchy-snapshot lag.

This is not a helper false negative. The corrected helper requires the two real navigation transitions and proves the collision state before the disputed tap. The returned success envelope proves only that WDA accepted a click; it does not prove the intended same-label element won.

## Raw evidence

- In `findings/evidence/round4-smoke-candidate2/04-mcp-ios-attempt3/helper/active/stdout.raw`, reply 20 is the successful `Mountains` back tap from the Denali detail. Its returned hierarchy is the Mountains category and contains all three relevant nodes: the `Landmarks` application root, an actual button with `identifier == "BackButton"` and `label == "Landmarks"`, and the selected tab button with `label == "Landmarks"`, `value == "1"`, and a non-`BackButton` identifier.
- Reply 21 reports `Tapped on "Landmarks". Updated hierarchy:` but remains on the Mountains category. It still contains the same `Landmarks` back button and selected tab and contains no `Golden Gate Bridge`. The helper therefore fails at its root-list outcome assertion, as recorded by `04-mcp-ios-attempt3/invocation/result.json` (`exit: 1`) and `invocation/stderr.log`.
- The runner stopped successfully at epoch `1791923784.88567`. The scoped screenshot began at `1791923839.47209`, roughly 54.6 seconds later, with no intervening app interaction. `04a-back-collision-diagnosis/after-runner-stop.png` (SHA-256 `b29b671658367b57bd925cf0b4ef6b37ccc6b19bfb1e2168d54506763d5ffd0f`) visibly remains on Mountains. Its capture metadata binds simulator `553C67C6-7C11-4976-85A0-148C9C8AC278` through the recorded ownership manifest.

## Source mechanism

`Sources/GrantivaCore/WDA/WDAClient.swift:80-110` sends an `/elements` predicate for every node whose `label` equals the requested text, excluding only `XCUIElementTypeApplication`, and unconditionally chooses `elements.first`. The exclusion correctly removes the application root, but it leaves both the navigation back button and selected tab eligible. Nothing in this path ranks `BackButton`, navigation ancestry, geometry, or another actionable-context signal. The observed stable Mountains state is consistent with WDA returning the selected tab first and Grantiva clicking it.

`Sources/GrantivaMCP/Tools/UITools.swift:151-156` already waits 500 ms before returning the hierarchy. Before the additive capture, snapshot timing remained a possible alternative explanation. The unchanged visual state roughly 55 seconds later eliminates that explanation for this run: the back navigation never occurred.

## Acceptance impact

The established L66 evidence explicitly requires application exclusion through the same-named `Landmarks` back button (`task-5-report.md:76-77`), and the approved retry helper additionally requires that back button to win in the current persistent-tab fixture. Attempt 3 is a direct live counterexample: the application is excluded, but another same-label non-application element wins or is otherwise clicked instead of the back button.

Do not relax the helper, substitute a coordinate tap, or accept the successful response text as proof. Product selection must deterministically resolve this live collision so the semantic `Landmarks` tap reaches the root list and returns a hierarchy containing `Golden Gate Bridge`. Preserve attempt 3 and the additive screenshot as the failing evidence. No additional live capture is needed to classify the failure.

## Review scope

This was a read-only review of retained raw output, capture metadata and frozen source. I did not run device commands, start a session, modify product/helper source, or rerun the flow.
