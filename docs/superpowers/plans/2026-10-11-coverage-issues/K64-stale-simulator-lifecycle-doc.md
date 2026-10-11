# SIMULATOR-LIFECYCLE.md at the repo root is an internal incident note with stale versions

Severity: docs
Component: docs
Platforms: n/a
Rows: B-D05.1 (cli); original brief D05 (changelog-move-shipped-unreleased)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Brief D05 criterion 1 (B-D05.1), as adapted in the matrix after CHANGELOG.md was removed (#179): no shipped file claims
a current version other than 2.1.0, and no internal status notes ship in the repository's user-facing docs.

## Actual
`grantiva --version` and Sources/GrantivaCore/Version.swift agree on 2.1.0 and CHANGELOG.md is gone, but
SIMULATOR-LIFECYCLE.md (repo root, 112 lines) is a dated incident write-up (findings/evidence/cov-cli/B-D05.1/versions.out):
```
29:2. **Ship 1.6.5** so the installed Homebrew binary (`/opt/homebrew/bin/grantiva`, currently 1.6.4) picks up the fix. Follow the usual release process, then verify with `grantiva --version` and a `simulator cleanup` dry run on the host.
```
Its line 3 reads `_2026-08-22. Status: code fix landed on branch `simulator-lifecycle-cleanup`; release and agent-fleet
actions below still open._`, and it names internal projects, worktrees and agent fleets. `simulator cleanup` has no
dry-run mode (Sources/GrantivaCLI/SimulatorCommand.swift:242-260). Nothing in README.md or docs/ links to the file.

## Repro
```
cd /Users/kyle/Developer/grantiva-cli
grantiva --version; cat Sources/GrantivaCore/Version.swift
grep -n "1\.6\.[0-9]\|Status:\|worktree" SIMULATOR-LIFECYCLE.md
grep -rn "SIMULATOR-LIFECYCLE" README.md docs Sources
```

## Evidence
- findings/evidence/cov-cli/B-D05.1/commands.txt, versions.out

## Suspected cause
- SIMULATOR-LIFECYCLE.md (repo root): an internal post-incident note committed with the code fix.

## Acceptance criteria
- SIMULATOR-LIFECYCLE.md is removed, or reduced to user-facing documentation of the simulator lifecycle (ensure,
  provenance ledger, teardown, cleanup) with no version claims, dates, branch names, internal project names or open
  action items, and linked from README.
- `grep -rn "1\.6\.[0-9]" --include=*.md .` outside docs/superpowers finds nothing that claims a current version.
- If kept, every command it mentions exists with the flags it shows (no `cleanup` dry run unless one is added).
