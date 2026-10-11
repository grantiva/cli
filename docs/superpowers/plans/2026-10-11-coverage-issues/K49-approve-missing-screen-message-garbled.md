# `diff approve <unknown screen>` prints a garbled "No captures found in No capture found for ..." message

Severity: ux
Component: cli
Platforms: both (CLI and the MCP `grantiva_vrt_approve` tool, which runs it)
Rows: CLI-150 (cli), IOS-114 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`No capture found for "NoSuchScreen"`, non-zero, existing captures untouched (matrix CLI-150; help: diff_approve.txt).

## Actual
CLI (findings/evidence/cov-cli/CLI-150/approve.err, approve.out), exit 1, Home.png unchanged:
```
Error: No captures found in No capture found for "NoSuchScreen". Run: grantiva diff capture
```
MCP `grantiva_vrt_approve {screens: ["Home; touch …/pwn-cov"]}` (findings/evidence/cov-ios/MCP-063/session/transcript.txt):
```
Approve failed:
Error: No captures found in No capture found for "Home; touch …/pwn-cov". Run: grantiva diff capture
```
(The quoting part of IOS-114 passed: no file was created.)

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k49 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k49 && cd /tmp/k49/ios
mkdir -p .grantiva/captures && printf 'fake' > .grantiva/captures/Home.png
shasum .grantiva/captures/Home.png
grantiva diff approve NoSuchScreen; echo "exit $?"
shasum .grantiva/captures/Home.png; ls .grantiva
```
Any file named `Home.png` in `.grantiva/captures` reproduces it (CLI-150 used a fake one); the image is never read.

## Evidence
- findings/evidence/cov-cli/CLI-150/commands.txt, approve.err, approve.out
- findings/evidence/cov-ios/MCP-063/commands.txt, session/transcript.txt

## Suspected cause
- Sources/GrantivaCLI/DiffCommand.swift:640-642: `throw GrantivaError.noCaptures("No capture found for \"\(screenName)\"")`
  passes a whole sentence where `noCaptures` expects a directory.
- Sources/GrantivaCore/GrantivaError.swift:54-55: `.noCaptures(let dir)` renders `"No captures found in \(dir). Run:
  grantiva diff capture"`.

## Acceptance criteria
- Re-running the repro: `Error: No capture found for "NoSuchScreen" in .grantiva/captures. Run: grantiva diff capture`
  (or the matrix text `No capture found for "NoSuchScreen"`), exit 1, Home.png unchanged, no baseline written.
- The MCP approve isError shows the same sentence once, under its `Approve failed:` prefix (prefix shape per K59).
- GrantivaCLITests/DiffCommandTests: approving an unknown screen throws an error whose description is the expected
  sentence and contains "No captures found in" zero times.
