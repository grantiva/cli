# `runner install` prints the same install path as `/private/tmp/…` on the run that extracts, and as `/tmp/…` on every later run and in `--json`

Severity: ux
Component: cli
Platforms: n/a (runner home handling, platform-independent; checked without a device)
Rows: EXTRA-02 [cli] (side finding of CLI-141 and B2-K45 [cli]; CLI-142's warning and error show the `/tmp` form too)
Regresses/extends: K104 (project directory `/private` stripped), fixed by CLI #194 for session and project directories only. This extends it to the runner home.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
One spelling of a path for one directory, across runs and between text and `--json`. After K104 the CLI's canonical
spelling is the realpath(3) one (`/private/tmp/x`), as `KeepAliveSessionStore.canonicalDirectory` records it.

## Actual
`GRANTIVA_RUNNER_HOME=rh` (relative) in a `/private/tmp/…/CLI-141` cwd, three runs
(findings/evidence/cov2-cli/CLI-141/install.out, second.out, json.out):
```
Runner installed at /private/tmp/claude-501/…/rows/CLI-141/rh/versions/1.1.28-grantiva.11+android-drivers-2/grantiva-runner
Runner already installed at /tmp/claude-501/…/rows/CLI-141/rh/versions/1.1.28-grantiva.11+android-drivers-2/grantiva-runner
  "path" : "\/tmp\/claude-501\/…\/rows\/CLI-141\/rh\/versions\/1.1.28-grantiva.11+android-drivers-2\/grantiva-runner",
```
With an absolute `GRANTIVA_RUNNER_HOME=$PWD/rh` the pattern is the same (findings/evidence/cov2-cli/B2-K45/first.out,
second.out). CLI-142's bundle warning and error name `/tmp/…/CLI-142/bin/grantiva_GrantivaCore.bundle` while the cwd
is `/private/tmp/…` (install_existing.err, install_fresh.err). Deterministic: the first run that creates the home prints
`/private`, and every later one prints `/tmp`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"; unset GRANTIVA_API_KEY
rm -rf /tmp/l27 && mkdir /tmp/l27 && cd /private/tmp/l27
GRANTIVA_RUNNER_HOME=rh grantiva runner install                       # "Runner installed at /private/tmp/l27/rh/…"
GRANTIVA_RUNNER_HOME=rh grantiva runner install                       # bug: "Runner already installed at /tmp/l27/rh/…"
GRANTIVA_RUNNER_HOME=rh grantiva runner install --json | jq -r .path  # bug: /tmp/l27/rh/…
```

## Evidence
- findings/evidence/cov2-cli/CLI-141/install.out, install.err, second.out, json.out, layout.out, commands.txt
- findings/evidence/cov2-cli/B2-K45/first.out, second.out, json.out, commands.txt
- findings/evidence/cov2-cli/CLI-142/install_existing.err, install_fresh.err, commands.txt
- docs/superpowers/plans/2026-10-11-coverage-issues/K104-project-directory-private-stripped.md

## Suspected cause
The spelling depends on whether the runner home existed when the process started.
- `Sources/GrantivaCore/Runner/RunnerManager.swift:199-204` (`resolveBaseDir`): `GRANTIVA_RUNNER_HOME` is made
  absolute with `URL(fileURLWithPath: override).standardizedFileURL.path`. Foundation's standardization drops a leading
  `/private` only when the resulting path exists. The comment on `KeepAliveSessionStore.canonicalDirectory`
  (`Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:82-91`) describes the same `/private` stripping and its
  existence condition. On the first run `rh` does not exist yet, so `baseDir` keeps `/private/tmp/…`. Once it exists,
  every later process gets `/tmp/…`.
- `baseDir` is a `static let` computed once (`RunnerManager.swift:195`). `currentInstallDir`, `binaryPath`
  (`:214-220`) and `DriverCommand`'s `Result(path: manager.runnerPath(), …)` (`Sources/GrantivaCLI/DriverCommand.swift:64-67`)
  all inherit its spelling.
- The bundle path in the CLI-142 messages is `bundle.bundlePath` of `resourceBundle` (`RunnerManager.swift:57,143,187`), which comes
  from how the binary was launched. It is a second, smaller source of the `/tmp` form.

Fix: canonicalize the runner home with realpath(3) of its deepest existing ancestor plus the remaining components (or
create it first and then `canonicalDirectory` it), so the spelling does not depend on existence. Apply the same to the
bundle path in messages.

## Acceptance criteria
- The three repro commands print the same path (the `/private/tmp/l27/rh/…` realpath form) in text and `--json`.
- The same holds with an absolute `GRANTIVA_RUNNER_HOME=$PWD/rh`, with the default `~/.grantiva/runner`, and in
  `doctor`'s Runner check and `runner version --json` if they print the path.
- The CLI-142 bundle warning and error name the bundle in the realpath spelling.
- Tests: GrantivaCoreTests (RunnerManager tests): `resolveBaseDir(environment: ["GRANTIVA_RUNNER_HOME":
  "<tmp>/missing/rh"])` and the same after creating it return identical strings. A relative value resolves against a cwd
  under `/tmp` to the `/private/tmp/…` form in both cases.
