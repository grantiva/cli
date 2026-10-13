# Task 9 source-window command inventory draft

Status: **PREPARATION ONLY; TASK 9 REMAINS GATED.** No verdict was populated and no build, test, `go list`, Swift command, device command, or product mutation was performed.

The machine-readable inventory is `task9-source-window-command-inventory-draft.json`. It binds candidate manifest `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, runner `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, and demo `84af7581b75134b0e417b254e4317d565f7b73c6`.

## Resolved Swift filters

Each focused command receives its own initially absent `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME`, with `GRANTIVA_API_KEY` unset. The inventory records the exact test cases behind these executable filters:

| Command ID | Exact filter | Rows |
|---|---|---|
| `swift-l53-targets` | `TargetOptionsTests\|SimulatorCommandTests.testTeardownRejectsAMalformedUDID\|RunnerSessionOutputTests.testSubdirectoryCycleUsesCanonicalProjectRelativeHops` | L53 E/F/P1/P4/P5 |
| `swift-l67-doctor` | `DoctorSelectionTests` | L67.1–.4 |
| `swift-l74-json` | `JSONOutputTests.testDatesEncodeAsISO8601` | L74.3 |
| `swift-l75-cycle` | `RunnerSessionOutputTests\|OutputRewriterTests` | L75.1–.5 |
| `swift-l81-doctor` | `DoctorTests` | L81.1–.7 |
| `swift-l82-attachment` | `RunnerLifecycleCommandTests\|AndroidPlatformTests` | L82.1/.2/.5 |
| `swift-l84-orphans` | `RunnerLifecycleCommandTests\|AndroidPlatformTests\|RunnerSessionStopperTests` | L84.1/.2/.4 |
| `swift-l85-selector` | `WDAClientTests\|UIToolsTests\|SessionLifecycleTests\|ToolErrorContractTests\|MCPServerTests` | L85.2/.3/.5 |
| `swift-pc5-launch-report` | `RunnerLifecycleCommandTests.testIOS` | PC.5 source half |
| `swift-ej3-paths` | `RunnerSessionOutputTests\|OutputRewriterTests\|FlowReferenceResolverTests` | EJ.3 source half |
| `swift-full` | full `swift test` | literal full-suite clauses only |

The JSON lists each concrete case relevant to the row. Class-level filters intentionally retain named sibling contracts where the literal criterion requires them; they are no longer generic placeholders.

## Resolved runner packages and tests

Focused Go execution uses only explicit packages and `-count=1`:

- L53 P2: `./pkg/cli`, exact `TestTestCommandRejectsEmptyDeviceBeforeDiscovery`.
- L83.1/.2/.4: `./pkg/device`, exact `TestDriverCleanupRemovesOnlyOwnedForwards`, whose table contains both `UIAutomator2` and `DeviceLab driver` and asserts exact owned socket/local-port removal, unrelated-port survival, and safe repeated cleanup.
- PC.9: `./pkg/driver/uiautomator2`, exact stop postcondition/deadline/cancellation cases.
- PC.10–.13: explicit `./pkg/driver/uiautomator2` and `./pkg/uiautomator2`, with the stable-target, hard cancellation, ordinary soft-deadline, step-context, and long-press-budget cases named in JSON.

The full Go package vector cannot be truthfully frozen by source inspection alone. The approved window first captures `go list ./...`, reviews its nonempty unique module-local lines, then expands those lines as separate literal argv entries for full `go test -count=1` and `go vet`. The JSON retains a non-executable marker for that required controller substitution; `./...` is prohibited in test/vet argv.

L53 P3 alone uses the separately authorized scratch `go build -o <window>/l53-runner-home/bin/grantiva-runner .` and its exact empty-device invocation. That binary cannot replace the frozen candidate runner.

## Separate evidence and gaps

- L67 still needs fresh public ambiguous doctor text/JSON and run-rejection commands; tests alone do not satisfy the public-output clauses.
- L70.1–.3 authorize frozen README/implementation/migration inspection only; they add no test command.
- L74.1/.2 are frozen-doc inspections. L74.4 joins fresh iOS and Android session JSON.
- L75.1–.3/.5 retain fresh scratch CLI commands for subdirectory, root, screens, absolute, `/tmp`, and `/private/tmp` forms in addition to source tests.
- L81.3 joins fresh doctor text/JSON. The focused fixtures themselves query no owner simulator.
- L82.3/.4, L83.3, and L84.3 remain Android live rows. L85.1/.4 remain iOS live rows; L85.4 also requires frozen demo inspection.
- PC.5 still needs its owned-iOS running-to-passed half. EJ.3 still joins both B3-L20 platform halves.
- L82.5, L83.4, L84.4, and L85.5 are provenance joins. Review, CI, merge, candidate freeze, completed Task 8, and campaign-close evidence are attached later; none authorizes a rebuild or repack in this window.
- AND-111 remains the separately bounded compile-only product row after the controller has proved an existing shutdown `cov4-android`. Its inventory entry is the frozen CLI `build build` command in a scratch copy of the frozen demo Android project; it requires byte-equivalent before/after `adb devices`, an unchanged shut-down AVD, and no install, boot, or launch. It is not a Swift/Go source test.

Every command must retain pre/post realpath, exact HEAD, empty status, manifest hash, tree hash, argv/cwd/environment/timestamps, raw streams, exit, and fresh-home/cache contents. A drift or command failure closes or fails the affected row without an in-place fix or rerun.
