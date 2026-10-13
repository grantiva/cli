# Review: iOS attempts 37–39 and Android flow contracts

Date: 2026-10-12

Scope was limited to the newly graded iOS attempt 37/38/39 rows and Android `flow-contracts-bulk-exact-rerun3` plus `B2-K23a-completion-rerun2`. I used matrix inputs and acceptance criteria from the regression worktree, CLI source at exact candidate `8f2cff67`, and the retained raw files. Android `flow-contracts-bulk-exact-rerun1` is an interrupted harness attempt and is excluded; there is no eligible rerun2 directory. Only rerun3 supports the bulk grades.

## Findings

### Re-review correction — B2-K22 [android] is supported

The initial review incorrectly equated the CLI narration `Runner ready` with a launched runner subprocess. Source order shows that narration means only that `RunnerManager.ensureAvailable()` found or installed the bundled binary: `RunCommand.swift:410-415` prints `Preparing runner...`, awaits binary availability, then prints `Runner ready`. The actual flow processing occurs later in `RunnerSession.runFlowFiles`: `RunnerSession.swift:404-447` reads each flow and calls `FlowReferenceResolver.resolve` before it creates the staged file and before the later runner-process execution path. Therefore the rerun3 empty-object error is raised before a runner subprocess starts even though the binary-availability narration already appeared.

`K22-empty/stderr.log` correctly names scalar, file, and commands forms; its empty `failure-screenshots.txt` proves no screenshot was produced. Exact-head `FlowStagingTests.swift:21-71` semantically covers unchanged inline commands, parent-relative nested `runFlow`, file+condition, and empty-object rejection. `RunSessionContractTests.swift:143-149` asserts the early invalid-argument error takes no failure screenshot. The B2-K22 pass grade is approved.

### Important — IOS-145 did not execute the README capture command as written

Matrix IOS-145 requires the README Local Workflow commands as written, with current exact-candidate README at `README.md:705-718`: bare `grantiva diff capture`, `grantiva diff compare`, and `grantiva diff approve`. Attempt 39 ran compare, approve, and the second compare bare, but `appfile-capture-five.command.txt` ran:

`grantiva diff capture --app-file <retained Landmarks.app> --simulator <owned-UDID> --json`

That capture is valid evidence for IOS-156, and the later bare commands prove five-new/approve/pass behavior against the resulting captures. It is not the documented capture command “as written”; `--app-file`, explicit simulator, and `--json` change target resolution, output mode, and build/install behavior. IOS-145 is therefore partial rather than a full pass unless the controller’s safety ruling explicitly permits those substitutions for documentation-example rows. The result note should disclose the substituted capture input instead of saying the documented workflow ran as written.

### Minor — IOS-129 uses the documented core flags but adds three behavior-affecting flags

README `README.md:74-80` shows `grantiva run --flow ... --keep-alive --logs`, followed by bare `grantiva hierarchy > state.xml`; matrix IOS-129 permits the flow path substitution. Attempt 37 additionally used `--no-build`, `--simulator <UDID>`, and `--ready-file`, while hierarchy added `--udid`. The evidence strongly proves keep-alive, log streaming, and a nonempty live XML hierarchy, so the functional claim is supported. The ledger should avoid the phrase “README ... as written” or disclose these safety/coordination additions. This is not the same defect as IOS-145 because the required feature flags and output remain directly exercised.

## Approved within scope

- **IOS-125:** exact no-config/no-bundle-ID input uses the literal flow header and passes the full browse flow.
- **IOS-127:** retained fixtures and successful positive/negative assertions distinguish step-over-header and CLI-over-both precedence.
- **IOS-130:** the bounded polling implementation observes the ready file while the process is live and records exact status `passed`; it preserves the documented loop semantics.
- **IOS-131:** XML, `--format json`, and the extra `--json` alias all return valid nonempty trees from the same held session. Explicit UDID selection is disclosed in the raw command construction.
- **IOS-040:** config-free `--app-file` run retains the app Info.plist, exact bundle ID, product hash/provenance, and a passing flow without a scheme.
- **IOS-158:** both requested `compare --capture` variants are exact: app-file install/capture and no-build with explicit installed bundle; both produce passing structured comparisons.
- **IOS-156:** exact app-file/owned-simulator capture produces all five configured screens. The same capture cannot simultaneously count as the bare IOS-145 documentation input without qualification.
- **B2-K18 [android]:** rerun3 supplies ephemeral run, ephemeral diff, and preserved-report run. The two ephemeral logs contain only the documented notice and no deleted temp path; the preserved block names report JSON/JUnit/Allure paths that exist. Android CI is unsupported and, under the existing campaign ruling, its exact early refusal in `B2-K25-ci-correction-rerun2/ci/` is the meaningful Android CI observation; it exposes no temp report path. Exact candidate `RunnerSessionOutputTests.swift:181-210` semantically covers ephemeral suppression, preserved output, and chunk boundaries and passed in the retained exact-head CI log.
- **B2-K22 [android]:** approved after the subprocess-order re-review above; the visible `Runner ready` line is binary preparation, not process launch.
- **B2-K23-a [android]:** the literal-header runtime, template-with-no-ID failure, APK-ID fallback, and explicit flag-over-conflicting-header runs match the required precedence. Candidate `TargetOptionsTests.swift:88-124` semantically asserts flag/app/config ordering, mismatch warnings, and Android built-ID selection; the exact-head CI log records those tests passing at lines 6665-6684. The unsupported Android CI ruling does not affect this row.

## Provenance note

The Android ledger correctly cites only `flow-contracts-bulk-exact-rerun3` for B2-K18/B2-K22 and joins the separately completed `B2-K23a-completion-rerun2` for K23-a. The retained rerun1 should remain preserved as an interrupted attempt, not silently treated as supporting output; no rerun2 bulk execution occurred.
