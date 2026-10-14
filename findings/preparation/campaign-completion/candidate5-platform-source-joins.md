# Candidate 5 platform source joins

**Status:** proposed for platform-owner verification. This does not edit either platform ledger.

Four canonical platform keys have requirements entirely satisfied by accepted current-candidate product tests:

| Key | Slice | Exact current proof | Reason |
|---|---|---|---|
| `B4-L65.2 [ios]` | ios | `ToolErrorContractTests.testScriptArgumentContractsThroughRegistryOnBothPlatforms` in `/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5/Tests/GrantivaMCPTests/ToolErrorContractTests.swift` (`a9ddd874284bca44cbbe6054e721ab17b286f529f52aec536bba364012779ba7`) | The product test loops over both platforms and pins the complete missing-steps text, isError envelope, distinct wrong-type/empty semantics, and no-session precedence. The requirement is wholly a test obligation. |
| `B4-L65.2 [android]` | android | `ToolErrorContractTests.testScriptArgumentContractsThroughRegistryOnBothPlatforms` in `/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5/Tests/GrantivaMCPTests/ToolErrorContractTests.swift` (`a9ddd874284bca44cbbe6054e721ab17b286f529f52aec536bba364012779ba7`) | The same product test explicitly executes Platform.android as well as Platform.ios and satisfies this wholly test-based requirement. |
| `B4-L66.3` | ios | `WDAClientTests.testPredicateSelectionUsesActualAttributesAndExcludesApplicationNodes` in `/Users/kyle/Developer/grantiva-cli/.worktrees/release-completion-candidate5/Tests/GrantivaCoreTests/WDAClientTests.swift` (`70eff3d7b910bd0262a2c52b6c49948543cd149a5db0b18445192b0f4c9566e6`) | The predicate-aware product test verifies actual selected WDA attributes, priority, exact clicked winner, literal escaping, and application-node exclusion. This row asks only for that test contract. |
| `B4-L64.1` | android | `TestLaunchFinalFatalDecision (before-return, healthy, after-return)` in `/Users/kyle/Developer/maestro-runner/.worktrees/release-completion-candidate5/pkg/driver/uiautomator2/launch_crash_after_draw_test.go` (`a08ec8f7f22d4564633f968a0385a53d6b14e24ede741bcc2e29568f0b98fd9a`) | The deterministic runner regression injects the fatal event at the exact status-read/success-decision boundary and includes healthy and after-return controls. The full uncached current reviewed-tree package passed; reviewed and merged runner trees are equal. This row is wholly a deterministic regression requirement, while live crash acceptance belongs to B4-L64.4. |

Source-only partials remain incomplete:

| Key | Joined source portion | Still required |
|---|---|---|
| `B4-L85.4` | Frozen demo source proves UIKit tab labels/order/symbols, literal heart identifier, three separate NavigationStack paths, and persisted selected-tab/path state. | Rendered geometry and live switch-away/switch-back retention remain required. |
| `B4-EJ.3 [ios]` | Accepted `swift-ej3-paths` current-tree source proof covers path-resolution and diagnostic construction only. | The iOS actor must still prove the exact four-hop runtime diagnostic, operand spellings, root/screens/subdirectory chains, and both aliases. |
| `B4-EJ.3 [android]` | Accepted `swift-ej3-paths` current-tree source proof covers path-resolution and diagnostic construction only. | The Android actor must still prove its separate exact four-hop runtime diagnostic and all operands/chains/aliases. |

No runtime result or prior-candidate verdict is transferred. The JSON companion records exact evidence hashes and canonical clauses.
