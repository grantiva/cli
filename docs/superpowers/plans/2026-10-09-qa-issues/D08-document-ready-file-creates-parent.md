# Document that --ready-file creates missing parent directories

Severity: docs
Platforms: cli, ios, android
Found by: CLI-DOCS-F13 (matrix rows CLI-121; also IOS-033, IOS-034, AND-033)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
README and help describe what happens when the ready file's directory does not exist. Source: README §Agent-Native
Features (README.md:85: "an unwritable path fails immediately rather than at the end of a long suite"); help: run.

## Actual
`ReadyFile.prepare` creates a missing parent with intermediate directories and fails only if that or the write probe
fails, so a typo in the directory part silently creates a directory. Neither README nor help says so:
```
  --ready-file <ready-file>
                          Write this file once the run reaches a terminal
                          state, containing its status. Deleted at startup, and
                          always written — a setup failure records `failed`
```

## Repro
```
cd $(mktemp -d) && grantiva run --no-build --ready-file does/not/exist/x.ready; ls -R does
```
`does/not/exist/x.ready` exists afterward (status `failed`, as no config is present).

## Evidence
- README.md:85; help/run.txt:71-78 (qa-cli worktree root); Sources/GrantivaCore/Runner/ReadyFile.swift:73-81

## Suspected cause
Docs gap; behavior is at Sources/GrantivaCore/Runner/ReadyFile.swift:73-81.

## Acceptance criteria
- README §Agent-Native Features and the `--ready-file` help say "Missing parent directories are created." (or, if
  creation is unwanted, the code stops creating them and the docs say the directory must exist).
- GrantivaCoreTests/ReadyFileTests already covers creation; add an assertion if the behavior changes.
