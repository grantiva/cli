# L85 back-priority source review

## Review boundary

- Reviewed exact source HEAD `bccc535ef91b24bd4147aef7437bae0866988b8c` against base `22055ff981ae1ffd5aaae69190d7af180f239162` in `/Users/kyle/Developer/grantiva-cli/.worktrees/fix4-back-priority`.
- The three-file diff is limited to `Sources/GrantivaCore/WDA/WDAClient.swift`, `Sources/GrantivaMCP/Tools/UITools.swift`, and `Tests/GrantivaCoreTests/WDAClientTests.swift`.
- Requirements came from the binding L85 brief, the candidate-2 source diagnosis, and the original L66 brief. This is a source/spec review. It makes no live-acceptance or merge claim; iOS 26/27 live proof remains root-owned and pending.

## Verdict

**Changes requested: one low-severity documentation defect.** The executable selector change and its behavioral tests otherwise satisfy the reviewed source requirements.

## Finding

### Low — public match contract still says the identifier stage uses WDA `name`

`Sources/GrantivaCore/WDA/WDAClient.swift:61-63` documents `LabelMatch` as label, then WDA `name`, then placeholder, and says `name` is equivalent to the accessibility identifier. The implementation at lines 247 and 262 queries the actual WDA `identifier`, and the original L66 acceptance criterion explicitly requires correcting this old-name equivalence. This public comment therefore contradicts both the accepted selector contract and the code. Update it to say accessibility `identifier`; it can also state that a matching navigation `BackButton` remains a `.label` match within the label stage.

`docs/mcp.md:189` correctly records `label -> identifier -> placeholder`, while the changed MCP tool description correctly exposes the within-label navigation-back preference.

## Source and test assessment

- The preferred predicate is constrained to the requested escaped label, the real `BackButton` identifier, and `XCUIElementTypeButton`; a hit reports `.label`.
- If the preferred query is empty, the prior broad label query remains first, followed by true identifier and placeholder queries. All broad queries retain application-root exclusion.
- The new collision test is behavioral rather than string-only: its selected-tab node appears first, has a different ID, and the assertion proves the navigation-back ID was clicked without issuing the broad query. The no-back control proves the former first-result behavior remains.
- Existing and adjusted tests cover true identifier and placeholder fallbacks, escaping in both preferred and broad predicates, application exclusion, unknown-selector/server errors, the single 400 retry path, and match annotations. Coordinate-tap code is outside the diff.
- The selection loop continues to share the existing retry and error handling. A 400 retries the same query once after resolving the session again; non-200 failures do not silently fall through.

## Independent test-evidence inspection

- Focused raw output at `task8-back-priority-tests/focused-green.raw` completed successfully and reports 28 `WDAClientTests`, zero failures.
- The controller's exact-HEAD full rerun at `task8-back-priority-tests/full-green.raw` completed with one failure outside this diff: `Tests/GrantivaCoreTests/SimulatorManagerTests.swift:503`, `testBootWaitingOnATwinsBootIssuesNoSecondBoot`, expected `Optional(true)` but observed `nil`. The raw footer therefore says that `GrantivaCoreTests` reported failures even though later test bundles completed successfully. This review does not relabel that run as a full pass or infer that the failure was caused by L85.
- I did not launch another test or device run.

## Remaining acceptance boundary

Source review cannot establish the real WDA collision result. Acceptance still requires the root-owned live sequence to capture the pre-tap application/back/tab collision, prove the semantic `Landmarks` tap reaches the root list containing Golden Gate Bridge, and preserve the selected/unselected tab and navigation-stack controls on the required iOS runtimes.

## Scoped documentation correction and test-evidence re-review

**Specification verdict: APPROVED.** Final HEAD `6cad3f2b4081f0862cd0e93140eda11c2816b9ba` resolves the sole source-review finding. Relative to reviewed implementation commit `bccc535ef91b24bd4147aef7437bae0866988b8c`, the only change is the two-line `LabelMatch` documentation correction in `Sources/GrantivaCore/WDA/WDAClient.swift`: it now names WDA's true `identifier` attribute rather than the obsolete `name` equivalence. The executable implementation, MCP description and tests are byte-identical to the previously reviewed versions. The final worktree is clean, and the recorded final file hashes match the actual three reviewed files.

**Quality/test-evidence verdict: APPROVED.** The earlier failed exact-implementation full run remains preserved in `task8-back-priority-tests/full-green.raw`: `GrantivaCoreTests` executed 975 tests with the single unchanged `SimulatorManagerTests.testBootWaitingOnATwinsBootIssuesNoSecondBoot` timing failure (`nil` versus `Optional(true)`), while the other target suites completed. It is not relabeled as passing.

The fresh retry `full-green-retry.raw` records all four target suites passing: MCP 281, Core 975, CLI 667 and API 101, totaling 2,024 tests with zero failures. `test-metadata.md` binds the retry to exact implementation commit `bccc535ef91b24bd4147aef7437bae0866988b8c`, the distinct fresh runner/Maestro homes, unset `GRANTIVA_API_KEY`, exact argv and timestamps. Because final HEAD changes only a source comment, this retry is valid implementation test evidence; required CI remains responsible for testing final HEAD.

This scoped approval does not claim a build, live iOS acceptance, CI, merge or replacement-candidate freeze. I performed no test, build or device execution.
