# `docs/plans/v2-swift-native-runner.md`, an internal "Proposed" planning note, ships in the public docs tree and presents 2.0.0 as the next release of a CLI that is now 2.1.0

Severity: docs
Component: docs
Platforms: n/a (repository content). Logical, no load dependence.
Rows: B-D05.1 [cli] (also noted under B2-K64 [cli], pass)
Regresses/extends: extends D05 (docs/superpowers/plans/2026-10-09-qa-issues/D05-changelog-move-shipped-unreleased.md, in git history; CHANGELOG fixed in #165 and removed in #179). The D05 criterion was narrowed for this pass to "no shipped file claims a version other than 2.1.0".
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11
Triage note: the K64 guard test deliberately treats `docs/plans/` as not shipped (see Suspected cause). The owner should rule whether `docs/plans/` counts as shipped; if it does not, close this as an expectation error and record the ruling.

## Expected
No file a reader of the repository or the release tarball sees as product documentation claims a grantiva version
other than 2.1.0, or describes a released version as upcoming. Internal planning notes live under `docs/superpowers/`
(excluded from the D05/K64 checks) or are marked historical.

## Actual
`grantiva --version` prints 2.1.0 and CHANGELOG.md is gone, but `docs/plans/v2-swift-native-runner.md` at c65fc17 opens:
```
# v2.0.0 — Swift-Native Runner

**Status:** Proposed
**Author:** Kyle
**Target cutover:** When the Swift implementation passes every flow in `grantiva-examples`
```
Its line 18 lists 0.9.0, 1.0.0, 1.0.1 and 1.1.0 as the releases of "this session"; `:36`, `:102`, `:112` and `:124`
plan a 2.0.0 / 2.0.0-rc1 that never shipped as described. Version scan (findings/evidence/cov2-cli/B-D05.1/versions2.out):
every version literal outside README.md:98 and docs/dump-hierarchy.md comes from this one file (14 hits). The file also
carries internal process notes (`:7`, `:81`, `:119`) that are not user documentation. Its own spec,
`docs/superpowers/specs/2026-10-07-android-support-design.md:19`, says the plan "is shelved".

## Repro
No device needed; from a clone of grantiva-cli at c65fc17.
```
git -C /Users/kyle/Developer/grantiva-cli/.worktrees/release-main show c65fc17:docs/plans/v2-swift-native-runner.md | head -5
cd /Users/kyle/Developer/grantiva-cli/.worktrees/release-main
grep -rn -o -E '[0-9]+\.[0-9]+\.[0-9]+[-+a-z0-9.]*' README.md docs/*.md docs/plans/*.md | sort | uniq -c | sort -rn
```

## Evidence
- findings/evidence/cov2-cli/B-D05.1/versions2.out, findings/evidence/cov2-cli/B-D05.1/commands.txt
- findings/cov2-cli-results.md rows B-D05.1 (fail) and B2-K64 (pass, names the same file)

## Suspected cause
- The note was never moved when the plan was shelved; nothing else references it (`grep -rn docs/plans` finds only the
  spec line above).
- `Tests/GrantivaCLITests/DocsContractTests.swift:16-27` (`shippedFiles()`) reads README.md and `docs/*.md` only, and
  its doc comment says "not the plans under docs/superpowers or docs/plans". So
  `testNoShippedMarkdownClaimsAnOldVersionOrCarriesAnIncidentNote` (`:71-79`) passes with this file in place by design.

## Acceptance criteria
- `docs/plans/v2-swift-native-runner.md` is moved under `docs/superpowers/` (or deleted), or gains a first line stating
  it is a shelved historical note that does not describe any release, with its internal process notes removed.
- `docs/plans/` is either gone or included in the shipped set: after the change, the version scan above prints no
  version other than 2.1.0 and the bundled runner stamp outside `docs/superpowers/`.
- If `docs/plans/` stays, `DocsContractTests.shippedFiles()` includes `docs/plans/*.md`, so
  `testNoShippedMarkdownClaimsAnOldVersionOrCarriesAnIncidentNote` (GrantivaCLITests) covers it; otherwise add a
  one-line assertion in the same test that `docs/plans` does not exist.
