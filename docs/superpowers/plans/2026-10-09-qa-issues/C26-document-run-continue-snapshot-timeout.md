# Document run's --continue-on-failure, --snapshot, and --timeout minimum

Severity: docs
Platforms: cli
Found by: CLI-F01 (matrix rows CLI-004)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
Every `run` flag is described outside `--help`, and the help states `--timeout`'s 30 s minimum. Source: matrix CLI-004;
README §Agent-Native Features; docs/android.md §Devices.

## Actual
`grep` finds no `--continue-on-failure`, `--snapshot` or `--timeout` in README.md, docs/*.md or CHANGELOG.md. The help
says `Default: 600 (10 min)` with no minimum, but:
```
$ grantiva run --timeout 0 --no-build
Error: --timeout must be at least 30 seconds.
Usage: grantiva run <options>
  See 'grantiva run --help' for more information.
```
(exit 64)

## Repro
```
grep -n -- '--snapshot\|--continue-on-failure\|--timeout' README.md docs/*.md CHANGELOG.md
grantiva run --help | sed -n '/--snapshot/,/--ready-file/p'
cd $(mktemp -d) && grantiva run --timeout 0 --no-build; echo rc=$?
```

## Evidence
- findings/evidence/cli/detect/run-validation.txt
- help/run.txt:56-70 (qa-cli worktree root)

## Suspected cause
Docs gap. The minimum is enforced at Sources/GrantivaCLI/RunCommand.swift:65 (`validate()`) but not stated in the
`--timeout` help string.

## Acceptance criteria
- README §Agent-Native Features describes `--snapshot failure|trailing|full`, `--continue-on-failure` (fail-fast is the
  default), and `--timeout` (default 600, minimum 30, ignored under `--keep-alive`).
- `run --help` for `--timeout` says "Minimum 30."
- Note that until C04 is fixed, these flags apply only to `flows:`/`--flow`; say so, or drop the note once C04 lands.
