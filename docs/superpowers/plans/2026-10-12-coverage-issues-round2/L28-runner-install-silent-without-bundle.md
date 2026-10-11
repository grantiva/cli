# `runner install` on a current install says nothing when the resource bundle is missing from beside the binary

Severity: contract
Component: cli (code or README; see the triage note)
Platforms: n/a (runner home handling; checked without a device)
Rows: EXTRA-03 [cli] (side finding of B-C01.1 [cli], which passes)
Regresses/extends: K48 (bundle mismatch message and residue), fixed by CLI #192. Incomplete: the README half and the code disagree for a missing bundle.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

Triage note: README's sentence can be read as covering only a bundle from another release. The code comment says
"nil when the bundle matches or is absent" on purpose. Either fix closes the row: warn, or reword README. A missing
bundle is the more likely breakage (a binary copied without its bundle, which B-C01.1 exercises), and the next fresh
install will fail on it, so the warning is the more useful choice.

## Expected
README `GRANTIVA_RUNNER_HOME` row (README:192 at c65fc17): "An existing install of the current version is used as it
is, without reading the bundle; `grantiva runner install` then warns when the bundle does not carry that runner." With
no bundle beside the binary, the bundle carries no runner either, and the next fresh install (new stamp, new
`GRANTIVA_RUNNER_HOME`, pruned `versions/`) will fail with "The grantiva_GrantivaCore.bundle resource bundle was not
found next to the grantiva executable…". `runner install` should warn now, as it does for a bundle from another release.

## Actual
Binary copied to `./bin/grantiva` without `grantiva_GrantivaCore.bundle`:
- Fresh home: exit 1 with a clear error, and no `versions/<stamp>/` left (findings/evidence/cov2-cli/B-C01.1/fresh.err).
  This half passes:
```
Extracting runner...
Error: The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable, so the embedded runner cannot be extracted. Reinstall grantiva, or keep the bundle beside the binary when copying it.
```
- Home with a current install: exit 0 in 0.019 s and no warning (findings/evidence/cov2-cli/B-C01.1/existing.out;
  existing.err empty):
```
Runner already installed at /tmp/claude-501/…/rows/B-C01.1/existing/versions/1.1.28-grantiva.11+android-drivers-2/grantiva-runner
Version: 1.1.28-grantiva.11
```
A bundle from another release does warn in the same situation (CLI-142, install_existing.err). Deterministic.

## Repro
```
export GRANTIVA_RUNNER_HOME=/tmp/l28/home; unset GRANTIVA_API_KEY
rm -rf /tmp/l28 && mkdir -p /tmp/l28/bin
"$HOME/.grantiva-qa/bin/grantiva" runner install                      # a current install, with the bundle
cp "$HOME/.grantiva-qa/bin/grantiva" /tmp/l28/bin/grantiva           # the binary only, no grantiva_GrantivaCore.bundle
/tmp/l28/bin/grantiva runner install; echo "exit=$?"                  # bug: exit=0, no Warning line
GRANTIVA_RUNNER_HOME=/tmp/l28/fresh /tmp/l28/bin/grantiva runner install; echo "exit=$?"   # exit=1: what the warning should foretell
```

## Evidence
- findings/evidence/cov2-cli/B-C01.1/existing.out, existing.err, fresh.err, fresh_tree.out, before.sha, after.sha, commands.txt
- findings/evidence/cov2-cli/CLI-142/install_existing.err (the warning for a bundle from another release)
- docs/superpowers/plans/2026-10-11-coverage-issues/K48-bundle-mismatch-message-and-residue.md

## Suspected cause
- `Sources/GrantivaCore/Runner/RunnerManager.swift:157-164` (`bundleMismatchWarning()`): `guard let bundle =
  resourceBundle else { return nil }`. The doc comment says "nil when the bundle matches or is absent".
  `resourceBundle` (`:57-71`) is nil when no candidate directory holds the bundle.
- The caller warns only on a non-nil result (`Sources/GrantivaCLI/DriverCommand.swift:50-55`).
- The fresh-install error text exists already (the `fresh.err` message, `RunnerManager.extractEmbedded`,
  `RunnerManager.swift:102-107`). Reuse its wording.
- `testTheShippedBundleRaisesNoWarning` (`Tests/GrantivaCoreTests/RunnerManagerTests.swift:568-572`) covers only the
  present-bundle case.

## Acceptance criteria
Choose one and close the row with it:
- (a, preferred) With a current install and no bundle, `runner install` exits 0 and prints one `Warning:` line naming the
  missing `grantiva_GrantivaCore.bundle`, saying the installed runner was left as it is and that a fresh install would
  fail. Use the same sentence shape as the other-release warning. `--json` stays a single document on stdout, with the
  warning on stderr.
- (b) README:192 reads "…warns when the bundle beside the binary is from another release; a missing bundle is reported
  only when an install is needed."
- For (a), tests in GrantivaCoreTests/RunnerManagerTests: a `bundleMismatchWarning(bundle: nil, …)` overload (or an
  injected bundle lookup) returns a warning that names `grantiva_GrantivaCore.bundle`. With the shipped bundle it still
  returns nil.
