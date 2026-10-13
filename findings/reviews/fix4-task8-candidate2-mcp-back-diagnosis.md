# Candidate 2 iOS MCP back-selection diagnosis

**Diagnosis verdict: STALE HELPER NAVIGATION ASSUMPTION; NO PRODUCT SELECTOR FAILURE.** At the point where the helper sends `grantiva_tap {label: "Landmarks"}`, the Denali detail hierarchy has no back button labeled Landmarks. The only eligible Landmarks element is the already-selected tab button; tapping it correctly preserves the Mountains/Denali navigation stack. The application root is excluded as required.

## Raw state and selection

- Request 18 successfully taps the quoted `Mount "Denali"` row. Its returned hierarchy and the independent request-19 tree both show the Denali detail screen.
- On that screen, the navigation back button is an `XCUIElementTypeButton` at x16/y62 with label `Mountains`, name/identifier `BackButton`. The visible title is `Mount "Denali"`.
- The only button labeled `Landmarks` is the selected tab at x67/y795 with value `1`. The hierarchy root is also labeled `Landmarks`, but it is `XCUIElementTypeApplication`, not a button.
- Request 20 sends `grantiva_tap {label: "Landmarks"}` and returns a good result with `Tapped on "Landmarks"`. The resulting hierarchy remains on Denali with the Mountains back button and selected Landmarks tab. That is the expected result of tapping the already-selected tab under the accepted persistent-navigation fixture.

The raw before/after trees therefore identify exactly which element won: the Landmarks tab button. They also rule out the feared regression in which the same-named application root is selected, because that root is not actionable and the tool returns a normal button tap while preserving the current app hierarchy.

## Contract comparison

The original L66 application-exclusion control required a real **Landmarks back button** to win while a same-named `XCUIElementTypeApplication` root was present. Prior accepted scripts first reached a state whose actual navigation back button was labeled Landmarks, asserted both the button and application root, then tapped Landmarks and required the root list containing Golden Gate Bridge.

The current helper reaches a deeper route: root list -> Mountains category -> Denali detail. Its immediate back path is Denali -> Mountains -> Landmarks. The accepted full-tab regression explicitly establishes that this Mountains stack survives tab switching. Expecting one `Landmarks` tap from Denali to return directly to Golden Gate both skips the real Mountains back step and conflicts with that accepted stack-preservation behavior.

Nothing in L66 requires a selected tab tap to pop a navigation stack. The criterion requires application-node exclusion and correct selector priority when an actual same-labeled actionable element exists. Request 20 exercises the selected tab rather than the intended back-button collision, so its missing Golden Gate text cannot diagnose product failure.

## Precise retry setup

Preserve this failed attempt. To retain the original criterion without weakening it, the helper should:

1. After the quoted Denali tap, assert that the current hierarchy contains the `Mountains` button with `identifier: BackButton`, the selected Landmarks tab, and the Landmarks application root.
2. Tap `Mountains` and require the returned category hierarchy to contain the actual `Landmarks` back button plus the same-named Landmarks application root.
3. Tap `Landmarks` from that category hierarchy and require the returned root list to contain `Golden Gate Bridge`.

This two-step unwind recreates the exact application-root/back-button collision on the current demo navigation path. It retains the winning-button and resulting-screen proof instead of dropping the control or substituting a generic successful tap.

The attempt-2 selector sequence through quoted Denali is valid supporting evidence, and the scoped phase stop exited 0. The MCP phase remains incomplete because coordinate and transport checks occur after the stale assertion.

**Spec diagnosis: no L66 product failure is evidenced; the intended back-button/application-root control was not set up by the helper.**

**Quality diagnosis: correct the fixture sequence to unwind Mountains first, then exercise the Landmarks back-button collision.**
