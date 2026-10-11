# `diff approve` / `grantiva_vrt_approve` stop at the first missing screen: later missing screens go unnamed, and screens before it are already approved

Severity: contract
Component: cli (shared by `grantiva diff approve` and MCP `grantiva_vrt_approve`, which spawns it)
Platforms: both (platform-independent; checked through MCP with no device)
Rows: B2-K60 [cli]
Regresses/extends: K60 (VRT tools shell string), fixed by CLI #195 (argv half holds, criterion 2's "fails naming the screens" not met); K49 (approve missing-screen message), fixed by CLI #191.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
K60 acceptance criterion 2: "approve fails naming the screens". With several requested screens missing, the error names
every one. K49 / help (diff_approve): a request with a missing screen exits non-zero and leaves existing state untouched,
so an approve that fails approves nothing.

## Actual
One capture (`.grantiva/captures/Home.png`) present. Three requested screens, none captured. Only the first is named
(findings/evidence/cov2-cli/B2-K60/approve_with_capture.requests.jsonl and .out):
```
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Home; touch pwned","$(touch pwned2)","`touch pwned3`"]}}}
{"id":1,"jsonrpc":"2.0","result":{"content":[{"text":"Error: No capture found for \"Home; touch pwned\" in .grantiva/captures. Run: grantiva diff capture","type":"text"}],"isError":true}}
```
The K60 shell half holds: no `pwned*` file is created (marker.out, marker2.out: `0`), and the names are passed verbatim.
The partial-approve half comes from reading the source (see Suspected cause). It was not run.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; unset GRANTIVA_API_KEY
rm -rf /tmp/l16 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l16 && cd /tmp/l16/ios
mkdir -p .grantiva/captures && echo iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg== | base64 -d > .grantiva/captures/Home.png
grantiva diff approve Missing1 Missing2 Missing3; echo "exit=$?"
# bug: names only "Missing1"
grantiva diff approve Home Missing1; echo "exit=$?"; ls .grantiva/baselines/
# bug: exits 1 naming Missing1, yet .grantiva/baselines/ now holds Home.png
```
MCP form: `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_vrt_approve","arguments":{"screens":["Missing1","Missing2","Missing3"]}}}`
after `initialize` against `grantiva mcp --project-dir /tmp/l16/ios`.

## Evidence
- findings/evidence/cov2-cli/B2-K60/approve_with_capture.requests.jsonl, approve_with_capture.out, approve.out
- findings/evidence/cov2-cli/B2-K60/marker.out, marker2.out (no shell), tests.out, commands.txt
- docs/superpowers/plans/2026-10-11-coverage-issues/K60-vrt-tools-shell-string.md, K49-approve-missing-screen-message-garbled.md

## Suspected cause
`Sources/GrantivaCLI/DiffCommand.swift:768-790` (`DiffCommand.approve`): one loop checks and saves each screen in turn.
The first missing capture throws `GrantivaError.notFound("No capture found for \"<name>\" …")` (`:781-783`), so later
names are never checked. Every screen before it has already been written by `store.save` (`:785`), so a failing approve
is also a partial approve. `testApproveRejectsRequestedScreenWithoutCapture`
(`Tests/GrantivaCLITests/DiffCommandTests.swift:158-177`) covers only a single missing screen.

Fix: resolve every requested name to its capture path first. If any are missing, throw one error naming all of them
and save nothing. Only then save.

## Acceptance criteria
- `diff approve A B C` with none captured exits non-zero with one error naming all three, for example `No captures found
  for "A", "B", "C" in .grantiva/captures. Run: grantiva diff capture`. A single missing screen keeps K49's sentence.
- `diff approve Home Missing` exits non-zero and writes no baseline (`.grantiva/baselines/` unchanged, no `Home.png`
  created or replaced).
- `grantiva_vrt_approve` returns the same text as an `isError` result.
- Tests: GrantivaCLITests/DiffCommandTests, (1) `approve(["A","B","C"], …)` with no captures throws, and the message
  contains all three names. (2) `approve(["Home","Missing"], …)` with Home captured throws, and a recording
  `BaselineStore` saw no `save` call.
