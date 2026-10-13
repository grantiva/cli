# Task 8 candidate 2 MCP back-fixture fix review

Scope: `task8-candidate2-mcp-back-fix-report.md`, its 19-line diff, and corrected SDD `task-8-candidate2-harness/mcp_smoke.py` at SHA-256 `d5d9aa43132be586abd605f06d6ebd2f65fe81e2a78fc14e09255f9ea86e6882`. This was a bounded static review; no live/device command or durable edit was performed.

## Verdicts

- **Specification compliance: APPROVED.** The helper now recreates the original L66 actionable-back-button versus same-named application-root collision on the current two-level Mountains navigation stack.
- **Code quality: APPROVED.** The predicates distinguish the navigation controls, selected tab, and application root; both transitions require good tool replies and semantic destination hierarchies. Coordinate and transport coverage remain unchanged.

## Review

The correction first binds the Denali state to an application root labeled Landmarks, an `XCUIElementTypeButton` labeled Mountains with exact identifier `BackButton`, and a separate selected Landmarks tab button whose identifier is not `BackButton` and whose value is `1`. These predicates match the retained attempt-2 hierarchy and prevent the selected tab or application root from standing in for the immediate navigation control.

The Mountains tap requires a good result and the expected success prefix, then parses the returned hierarchy. Requiring that destination to be the Landmarks application with an actual Landmarks/`BackButton` establishes that the Mountains back control won despite the same label also appearing in Denali content. It also proves arrival at the category level needed for the original collision.

At the category level, the hierarchy root itself supplies the same-named `XCUIElementTypeApplication`, while the explicit Landmarks/`BackButton` predicate supplies the actionable candidate. The next Landmarks tap again requires a good result and success prefix. Its returned hierarchy must remain the Landmarks application and contain Golden Gate Bridge, proving the navigation back button won and returned to the root list. A tab selection or application-root match could not satisfy that transition.

The fix therefore preserves rather than relaxes application-root exclusion. It does not replace semantic selection with coordinates, omit either hierarchy transition, or treat success text alone as proof. The existing selected/unselected identifier checks, placeholder annotation, quoted-label request/reply, missing-selector failure, live coordinate derivation, large-response pairs, small responses, notifications, and unique-ID assertions are unchanged.

Before retry execution, copy this exact reviewed helper to the flat durable `findings/tools/round4-smoke-candidate2/mcp_smoke.py` path and retain the executed helper copy/hash with the fresh output.
