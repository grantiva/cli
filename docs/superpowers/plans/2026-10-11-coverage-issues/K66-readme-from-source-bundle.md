# README's "From source" install copies only the binary, which then cannot extract the runner

Severity: docs
Component: docs
Platforms: n/a
Rows: EXTRA-04 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Following README "From source" gives a working `grantiva`: `runner install` (and every device command) can extract the
embedded runner.

## Actual
README:20-23:
```
git clone https://github.com/grantiva/cli.git
cd cli
swift build -c release
cp .build/release/grantiva /usr/local/bin/grantiva
```
A binary without `grantiva_GrantivaCore.bundle` beside it (findings/evidence/cov-cli/B-C01.1/fresh.err):
```
Extracting runner...
Error: The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable, so the embedded runner cannot be extracted. Reinstall grantiva, or keep the bundle beside the binary when copying it.
```

## Repro
```
rm -rf /tmp/k66 && git clone -q /Users/kyle/Developer/grantiva-cli /tmp/k66/cli && cd /tmp/k66/cli
swift build -c release
mkdir -p /tmp/k66/bin && cp .build/release/grantiva /tmp/k66/bin/grantiva       # README step, to a scratch dir
GRANTIVA_RUNNER_HOME=/tmp/k66/rh /tmp/k66/bin/grantiva runner install; echo "exit $?"
cp -R .build/release/grantiva_GrantivaCore.bundle /tmp/k66/bin/
GRANTIVA_RUNNER_HOME=/tmp/k66/rh /tmp/k66/bin/grantiva runner install; echo "exit $?"   # works
```
(The build needs the runner tarballs in Sources/GrantivaCore/Resources, as the release build does.)

## Evidence
- findings/evidence/cov-cli/B-C01.1/commands.txt, fresh.err

## Suspected cause
- README.md:20-23 omits the resource bundle. The error text itself (Sources/GrantivaCore/Runner/RunnerManager.swift:87-91)
  already says to keep the bundle beside the binary.

## Acceptance criteria
- README "From source" copies both: `cp -R .build/release/grantiva .build/release/grantiva_GrantivaCore.bundle
  /usr/local/bin/` (or installs into a prefix directory and links the binary), and says why the bundle must sit beside
  the binary.
- Following the new steps exactly, `grantiva runner install` exits 0.
