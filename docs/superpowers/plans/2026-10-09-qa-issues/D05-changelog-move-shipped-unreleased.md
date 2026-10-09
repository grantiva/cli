# Move shipped Unreleased entries under the version that contains them

Severity: docs
Platforms: cli, android
Found by: CLI-DOCS-F08 (matrix rows CLI-116)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
The CHANGELOG entry for the version `--version` prints describes that build. Source: CHANGELOG.md (`## 2.0.1 — 2026-10-07`).

## Actual
The binary under test prints `2.0.1` and ships `emulator`, `--platform`, the Android MCP tools and the other features
listed under `## Unreleased` (CHANGELOG.md:3-38), above `## 2.0.1 — 2026-10-07` (CHANGELOG.md:40). A user cannot tell
which entry describes their build.

## Repro
```
grantiva --version            # 2.0.1
grantiva emulator --help      # exists
grep -n '^## ' CHANGELOG.md
```

## Evidence
- CHANGELOG.md:3-38, :40; help/emulator.txt (qa-cli worktree root)

## Suspected cause
The version string was not bumped when the Android work merged after the 2.0.1 tag (or the build was cut from main with
the old version constant). Find the constant with `grep -rn '"2.0.1"' Sources`.

## Acceptance criteria
- Either bump the version for builds containing the Unreleased work (e.g. 2.1.0-dev on main) or move the entries under
  the release that ships them; `grantiva --version` and the CHANGELOG heading agree.
- Release checklist (or the release workflow) checks that `## Unreleased` is empty when a tag is cut.
