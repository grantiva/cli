# `runner install` says "Extracting runner..." when the install is already current and nothing is extracted

Severity: ux
Component: cli
Platforms: n/a
Rows: CLI-084 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`runner install` twice: both exit 0 and the second is a no-op (README:38, matrix CLI-084). Narration describes what
happened: no "Extracting" line when the installed stamp already matches; for example `Runner already installed`.

## Actual
Both runs print the same narration (findings/evidence/cov-cli/CLI-084/first.err, second.err, second.out):
```
Extracting runner...
Runner installed at /Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.9+android-drivers-2/grantiva-runner
Version: 1.1.28-grantiva.9
```
while the binary's mtime and inode are unchanged (mtime.out: `1791695021 189208875` before and after).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
export GRANTIVA_RUNNER_HOME=/tmp/k45/rh; rm -rf /tmp/k45
grantiva runner install          # fresh: extracting is true
B=$GRANTIVA_RUNNER_HOME/versions/1.1.28-grantiva.9+android-drivers-2/grantiva-runner; stat -f "%m %i" $B
grantiva runner install          # current: still says "Extracting runner..."
stat -f "%m %i" $B
```

## Evidence
- findings/evidence/cov-cli/CLI-084/commands.txt, first.err, second.err, second.out, mtime.out

## Suspected cause
- Sources/GrantivaCLI/DriverCommand.swift:30-33: `options.note("Extracting runner...")` before
  `manager.ensureAvailable()`.
- Sources/GrantivaCore/Runner/RunnerManager.swift:205-227 (`installIfNeeded`): returns early at :223-227 when the stamp
  matches; `onInstalled` (:213, used at :172-179) runs only after a fresh install, but nothing tells the caller which
  happened. `RunnerManager.ensureAvailable` returns `Void`.

## Acceptance criteria
- Re-running the repro: the first install prints `Extracting runner...` (or `Installing runner ...`); the second prints
  no "Extracting" line, and its result says the runner was already installed (text: `Runner already installed at ...`;
  `--json`: `"status": "current"` or an `"extracted": false` field, documented in the help or README).
- `run`, `diff capture` and `runner start` ("Preparing runner..." narration) stay as they are, or use the same signal.
- GrantivaCoreTests/RunnerManagerTests: `installIfNeeded` reports installed vs already-current (return value or
  callback); GrantivaCLITests (RunnerLifecycleCommandTests or InstallCommandTests): the second install's narration has
  no "Extracting".
