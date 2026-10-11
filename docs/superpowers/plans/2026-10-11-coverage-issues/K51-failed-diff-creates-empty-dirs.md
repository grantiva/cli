# A failing `diff compare` (and the MCP compare tool) leaves an empty `.grantiva/captures/diffs` directory

Severity: ux
Component: cli
Platforms: both (`captures/diffs` on iOS, `captures/android/diffs` on Android)
Rows: EXTRA-02 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
A command that fails because there is nothing to compare creates no directories in the project.

## Actual
In an empty project, one MCP session per platform calling `grantiva_vrt_capture`, `grantiva_vrt_compare`,
`grantiva_vrt_approve` (all isError) left `.grantiva/captures/diffs` and `.grantiva/captures/android/diffs` behind
(findings/evidence/cov-cli/MCP-033/commands.txt, closing note). The compare result:
```
{"id":6,...,"result":{"content":[{"text":"Error: No captures found in .grantiva/captures. Run: grantiva diff capture","type":"text"}],"isError":true}}
```
The CLI `diff compare` does the same (the MCP tool runs it). EXTRA-02's note also names `diff approve`; in source only
compare creates the directory (`diff approve` and the capture tool fail before creating anything).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k51 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k51
mkdir /tmp/k51/empty && cd /tmp/k51/empty
grantiva diff compare --platform ios; echo "exit $?"; find .grantiva
rm -rf .grantiva; grantiva diff compare --platform android; echo "exit $?"; find .grantiva
rm -rf .grantiva; grantiva diff approve --platform ios; echo "exit $?"; find .grantiva 2>&1
```
Today: exit 1 with `No captures found ...`, and `find` lists `.grantiva/captures/diffs` (or `.grantiva/captures/android/diffs`).

## Evidence
- findings/evidence/cov-cli/MCP-033/commands.txt (note on the left-behind directories), empty_ios.out, empty_android.out,
  empty_ios.requests.jsonl

## Suspected cause
- Sources/GrantivaCLI/DiffCommand.swift:266 (`diffDir = "\(captureDir)/diffs"`) and :379-383: `diff compare` creates
  `diffDir` with intermediate directories before the `guard fm.fileExists(atPath: captureDir)` at :385-388 and the
  empty-capture check at :401-403. Creating `diffs` with `withIntermediateDirectories: true` also creates `captures/`.
- `diff approve` (DiffCommand.swift:446-461) checks captures first and creates nothing.

## Acceptance criteria
- Re-running the repro: every command exits 1 with its message and `find .grantiva` prints nothing (no `.grantiva`).
- With captures present, `diff compare` still creates `diffs/` and writes diff images as today.
- GrantivaCLITests/DiffCommandTests: `diff compare` in a temp directory with no captures throws `noCaptures` and the
  directory has no `.grantiva` afterwards.
