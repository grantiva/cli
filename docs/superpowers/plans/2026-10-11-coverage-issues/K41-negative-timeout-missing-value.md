# `run --timeout -1` reports a missing value instead of an invalid one

Severity: ux
Component: cli
Platforms: n/a (argument parsing)
Rows: CLI-056 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`--timeout -1` is a usage error about the value (exit 64), for example `--timeout must be at least 30 seconds.` (the
check RunCommand.validate already makes) or an invalid-value error (matrix CLI-056; help: run.txt).

## Actual
findings/evidence/cov-cli/CLI-056/neg.err, exit 64:
```
Error: Missing value for '--timeout <timeout>'
Help:  --timeout <timeout>  Max seconds to wait for the runner subprocess before killing it with SIGTERM. Default: 600 (10 min). Minimum 30. Ignored under --keep-alive. Bump this for long multi-flow suites.
```
A value was given; ArgumentParser reads `-1` as an option. `--timeout abc` is reported correctly (`The value 'abc' is
invalid`, abc.err). A `--ready-file` passed with `-1` is also not written, because parsing fails before `validate()`
writes it (RunCommand.swift:66-77); untested, follows from the code.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k41 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k41 && cd /tmp/k41/ios
grantiva run --timeout -1; echo "exit $?"
grantiva run --timeout=-1; echo "exit $?"        # reaches validate(): "--timeout must be at least 30 seconds."
grantiva run --timeout -1 --ready-file r.ready; ls r.ready
grantiva hierarchy --timeout -1; echo "exit $?"  # Double option, same parse
```

## Evidence
- findings/evidence/cov-cli/CLI-056/commands.txt (listed under the CLI-055 cwd), abc.err, neg.err

## Suspected cause
- Sources/GrantivaCLI/RunCommand.swift:51-52: `@Option(name: .long, ...) var timeout: Int = 600` uses default parsing,
  in which a token starting with `-` is never taken as the value. Same for HierarchyCommand.swift:38-39 (`Double`),
  RecordCommand `--duration`, and any other numeric option.
- Not checked: whether ArgumentParser's `parsing: .unconditional` on these options is acceptable (it would also take
  `--timeout --json` as a value, which then fails as non-numeric, which is fine).

## Acceptance criteria
- `grantiva run --timeout -1`: exit 64 with `--timeout must be at least 30 seconds.` (same as `--timeout=-1` and
  `--timeout 5`), and `--ready-file` given with it is written with `"status": "failed"` and that `error`.
- `grantiva hierarchy --timeout -1` and `grantiva record --duration -1`: exit 64 with their own range message.
- GrantivaCLITests/RunCommandTests: `RunCommand.parse(["--timeout", "-1"])` (or `parseAsRoot`) yields the range error,
  not "Missing value".
