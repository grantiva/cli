# Round-3 CLI and documentation triage

## Scope and conclusion

This review classifies the seven remaining CLI-slice failures plus Android B2-K89 against the binding round-3 matrix, shared constraints, candidate `8f2cff67`, and preserved raw evidence. It proposes no matrix or product edit.

The smallest supported disposition is four groups:

1. **Refresh the post-L63 help corpus and its evidence references**: CLI-003, D2-47, N3-16. These are one stale-corpus correction, not three product defects.
2. **Apply the accepted single usage-error shape to old rows**: CLI-045 and the fourth leg of CLI-145. These are matrix expectation corrections.
3. **Apply L29's build-only flag decision to the older help inventory**: D2-27. This is a matrix expectation correction.
4. **Fix the candidate's doctor section assignment**: CLI-025. This is a product behavior defect against the accepted criterion.

Android B2-K89 needs an **evidence-source correction and regrade**, not a README product change: the audit read the landmarks demo's README from its runtime cwd. The candidate CLI README already states the mixed-case exit code and JSON verdict exactly as required.

L63 is already fixed in the product. L64-L66 are already allocated and none of these findings should be folded into or used to relax them.

## Proposed correction group 1: post-L63 help corpus

### CLI-003

**Exact expectation.** Matrix line 102 requires all 172 regenerated help pages to exit 0 with `OVERVIEW`, `USAGE`, and `OPTIONS`, and to be byte-identical to `findings/help/*.txt`.

**Observed.** `findings/evidence/cov3-cli/CLI-003/regen.out` records all 172 pages with the required structure and exit status; 171 are byte-identical. `simulator_teardown.diff` shows the sole delta: candidate `8f2cff67` adds the L63 sentence explaining that the stopped run's WebDriverAgent `xcodebuild` and `simctl diagnose` are ended before the runner home is removed.

**Disposition.** Supported expectation/evidence correction. Regenerate the canonical corpus from `8f2cff67` and retain the 172-page structural proof. The candidate text is the accepted L63 fix, so reverting it to satisfy the older corpus would be wrong.

### D2-47

**Exact expectation.** Matrix line 1459 requires 17 selected pages to match the round-2/fix-wave corpus, including `simulator teardown`.

**Observed.** `findings/evidence/cov3-cli/D2-47/` records 16 exact matches and the same single L63 addition on `simulator teardown` as CLI-003.

**Disposition.** Same evidence correction as CLI-003. Point D2-47 at the regenerated post-L63 corpus; do not create a separate product brief.

### N3-16

**Exact expectation.** Matrix line 1569 requires the round-3 additions to be present in README/docs, no shipped runner-lineage wording, and help pages to match the fix-wave corpus.

**Observed.** `findings/evidence/cov3-cli/N3-16/` supports the documentation and lineage clauses. Its only failed clause is the same pre-L63 `simulator_teardown.txt` comparison.

**Disposition.** Same evidence correction. After the one corpus refresh, re-evaluate all three rows from the preserved raw comparisons. The controller's independent 172-page regeneration also found every page structurally valid and only `simulator_teardown` changed, which is consistent with these captures.

## Proposed correction group 2: usage-error exit shape

### CLI-045

**Exact expectation.** Matrix line 163 still says Android `run --device … --emulator …` emits the mutual-exclusion message and exits 1 before device work.

**Observed.** `findings/evidence/cov3-cli/CLI-045/` has the exact message before device work, but exit 64 with `Error:`, `Usage:`, and `See '… --help'` lines.

**Binding newer rule.** `shared-constraints.md:32` defines the round-3 single usage-error shape for `--device`/`--emulator`: exit 64 with those three elements.

**Disposition.** Correct CLI-045's expected exit and shape to the accepted round-3 rule, then pass it from existing evidence. No product fix.

### CLI-145

**Exact expectation.** Matrix line 260 expects all four `record` rejections to exit 1 and notes the device/emulator inconsistency as M19.

**Observed.** `findings/evidence/cov3-cli/CLI-145/` shows the three other-platform errors still use the expected long form and exit 1. Only the same-platform `--device` plus `--emulator` conflict uses the accepted exit-64 usage shape.

**Disposition.** Correct only the fourth leg to exit 64 with `Error`/`Usage`/`See`; retain exit 1 and exact long-form wording for the three platform errors. Remove or resolve the stale M19 note because the shared constraint records the chosen behavior. Group with CLI-045 rather than opening another brief.

## Proposed correction group 3: L29 headless inventory

### D2-27

**Exact expectation.** Matrix line 1439 names seven help pages, including `build build`, and expects each to contain `--headless` with the environment/CI/window wording.

**Observed.** The valid replay is `findings/evidence/cov3-cli/D2-27/helps_r3.out` (the earlier malformed capture remains disclosed). The six commands that can boot or select an emulator contain the required wording. `build build` has no `--headless` option.

**Binding newer decision.** L29 intentionally removes device-selection/boot flags from the build-only surface; the CLI report's B3-L29 evidence separately confirms `build build` help omits the flags while legacy hidden parsing remains accepted pending its other semantics.

**Disposition.** Correct D2-27 to inventory six pages by removing `build build`; keep the text requirement unchanged for those six. Pass from `helps_r3.out`. Adding a visible no-effect flag back to `build build` would conflict with L29.

## Proposed product documentation/behavior group: doctor section semantics

### CLI-025

**Exact expectation.** Matrix line 136 requires `run` to reject an ambiguous Xcode-plus-Gradle directory, while `doctor` reports `Platform  Found both…` under **Advisory** and exits 0. It explicitly ties the behavior to C12's advice alternative and K35's rule that advisory checks do not fail the exit code.

**Observed.** `findings/evidence/cov3-cli/CLI-025/` shows `run` fully conforming. Doctor exits 0 and reports the expected warning/fix, but text places `Platform` under **Project** and JSON uses `section: "Project"`. Toolchain checks appear under Advisory.

**Candidate source.** `Sources/GrantivaCLI/DoctorCommand.swift:51-59` constructs the ambiguous-platform `DoctorCheck` with `section: .project`. `Sources/GrantivaCore/Doctor/DoctorCheck.swift:16-24` defines distinct Advisory and Project sections and documents Advisory as the home for checks that cannot fail doctor when no single platform is detected.

**Disposition.** Product behavior fix, narrowly changing the ambiguous-platform advice to `.advisory` and adding/adjusting a doctor output/JSON test that asserts the section and exit 0. Do not correct the matrix to Project: that would soften the accepted Advisory requirement. This can be one new post-L66 brief because neither the stale corpus, usage exits, nor L29 shares its cause.

## Android B2-K89: the claimed README omission is an evidence-source error

**Exact expectation.** Matrix line 1334 requires no-baseline and mixed-baseline comparisons to be non-passing, JSON `passed: false`, MCP parity, and the README diff section to state the mixed-case exit behavior.

**Runtime evidence.** Android `B2-K89-exact/01.out` shows the no-baseline headline, text exit 1, JSON exit 1, and `passed: false`. `B2-K89-mixed-retry/01.out` shows one passing baseline plus four `new_screen` results, `? Visual diff incomplete…`, and text/JSON exit 1. Its MCP transcript returns `passed: false` with the same mixed statuses.

**Why the documentation failure is unsupported.** `B2-K89-mixed-retry/readme-audit.txt` says it ran `sed -n '450,478p' README.md` from the Android demo runtime cwd recorded in `commands.txt`. That cwd is the scratch landmarks-demo `android/` directory, so the file inspected was not the Grantiva CLI README. The audit's claimed “round-3 source commit 8f2cff67” provenance is therefore false.

The actual candidate at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` is exactly `8f2cff67`. Its `README.md:726-729` says `diff compare` exits 0 only when every screen has a baseline and passes, exits 1 when a screen has no baseline, names both the no-baseline and partially missing `Visual diff incomplete` cases, and says JSON has `"passed": false` in both. It also preserves `ci run`'s distinct first-run behavior.

**Disposition.** Regrade the Android B2-K89 line to pass using the existing runtime/MCP evidence plus a corrected read-only audit of candidate README lines 726-729. Preserve the faulty audit as provenance, but do not open a product documentation fix and do not change the accepted requirement.

## Minimal Task 6 actions

| Group | Rows | Action | Product change |
|---|---|---|---|
| Post-L63 corpus | CLI-003, D2-47, N3-16 | Regenerate/cite the canonical 172-page corpus at `8f2cff67`; regrade from existing comparisons | No |
| Usage shape | CLI-045, CLI-145 fourth leg | Correct stale exit-1 expectations to the accepted exit-64 usage shape | No |
| L29 inventory | D2-27 | Remove `build build` from this `--headless` inventory; retain six-page wording | No |
| Doctor section | CLI-025 | Move ambiguous-platform advice from Project to Advisory and test text/JSON section | Yes, one narrow brief after L66 |
| Wrong README audited | Android B2-K89 | Replace demo-README audit with candidate README citation; regrade pass | No |

This grouping resolves six CLI failures through three expectation/evidence corrections, leaves CLI-025 as the sole product behavior item among the seven, and removes the unsupported B2-K89 documentation omission without weakening its mixed-verdict contract.
