# Task 8 candidate 2 MCP back-navigation fixture correction

## Scope

Prepared one SDD-only MCP helper correction from the independent back-selection diagnosis. The durable helper, product source, candidate, retained attempts, devices, sessions, and evidence were not modified or executed.

## Correction

After the quoted Denali tap, the helper now requires the hierarchy root to be the `Landmarks` application, the immediate navigation control to be an `XCUIElementTypeButton` with identifier `BackButton` and label `Mountains`, and the separate selected `Landmarks` tab to be a button with value `1` that is not the back button. It taps `Mountains`, requires a good reply with the exact success prefix, parses the returned category hierarchy, and requires the real `Landmarks` back button alongside the same-named application root. It then taps `Landmarks`, requires the exact success prefix, and proves the resulting `Landmarks` application root contains `Golden Gate Bridge`.

This preserves the application-root exclusion and winning-back-button control on the persistent navigation stack. It does not replace either back action with coordinates or a selected-tab action. The complete prior selector sequence, quoted-label transport behavior, good-reply checks, coordinate control, and later MCP assertions remain intact.

## Verification

- The corrected helper compiles and parses as Python.
- The retained attempt-2 request-19 raw tree satisfies the exact Denali-detail predicates: `Landmarks` application root, `Mountains`/`BackButton`, and a distinct selected `Landmarks` tab.
- Synthetic category and root-list trees satisfy the next-level `Landmarks`/`BackButton` and `Golden Gate Bridge` predicates.
- Negative synthetic trees containing only the selected `Landmarks` tab or application root cannot satisfy the back-button predicate.
- The scoped diff is `task8-candidate2-mcp-back-fix.diff` and is based on the current durable MCP helper.
