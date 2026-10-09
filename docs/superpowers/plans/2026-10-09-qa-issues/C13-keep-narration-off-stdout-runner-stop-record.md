# Keep narration off stdout in runner stop and record

Severity: contract
Platforms: cli, ios
Found by: CLI-F02, CLI-F15 (matrix rows CLI-086, CLI-102)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
stdout carries only the result; commentary goes to stderr. Source: README §stdout is the result, stderr is the commentary
(README.md:314).

## Actual
`runner stop` with no session (exit 0):
```
$ grantiva runner stop 2>/dev/null
No active session found.
```
`record` passes `simctl io recordVideo`'s own narration to stdout before Grantiva's result lines:
```
Recording completed. Writing to disk.

Wrote video to: .../rec3.mp4
Recording: .../rec3.mp4
Frame report: .../rec3.json
  500ms -> 0ms: .../rec3-frames/000500ms.png
  1500ms -> 0ms: .../rec3-frames/001500ms.png
```
(Also seen, not triaged: both frames report `-> 0ms`.)

## Repro
```
cd $(mktemp -d) && grantiva runner stop 2>/dev/null       # prints the line
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
grantiva record --duration 2 --frames-at 500,1500 --simulator "$udid" --output /tmp/c13.mp4 2>/dev/null | head -3
```

## Evidence
- findings/evidence/cli/detect/misc-validation.txt (lines 60-62), findings/evidence/cli/json/forced-failures.txt
- findings/evidence/cli/record/record-valid.stdout, findings/evidence/cli/record/notes.txt

## Suspected cause
Sources/GrantivaCLI/DriverCommand.swift:627 writes "No active session found." with `Output.line` (stdout).
Sources/GrantivaCore/Platform/IOSPlatform.swift:130-139: the `simctl io recordVideo` Process redirects only
`standardError`; its stdout is inherited.

## Acceptance criteria
- Re-running the repro: `runner stop 2>/dev/null` prints nothing (the message goes to stderr; `--json` still prints
  `{"status":"not_running"}`); `record ... 2>/dev/null` stdout starts with `Recording:`.
- Set the recorder's `standardOutput` to the same log file (or `/dev/null`).
- GrantivaCLITests/OutputStreamContractTests: assert `runner stop` with no session writes nothing to stdout.
- GrantivaCoreTests/IOSPlatformTests: assert the recordVideo process has a non-inherited `standardOutput`.

## iOS detail (IOS-F26)
`record --json` on iOS puts simctl's narration ahead of the JSON, so `json.load` fails at char 0:
```
Recording completed. Writing to disk.

Wrote video to: /private/tmp/qa-ios/rec.mp4
{
  "frames" : [ { "actualMilliseconds" : 0, "path" : "/private/tmp/qa-ios/rec-frames/000500ms.png", ...
```
Also, `--output rec.mp4` produces a QuickTime MOV container (`file rec.mp4`), not MPEG-4.
Repro:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva record --simulator qa-ios-1 --duration 4 --output /tmp/rec.mp4 --frames-at 500,1500,3500 --json 2>/dev/null \
  | python3 -c 'import json,sys; json.load(sys.stdin)'; file /tmp/rec.mp4
```
Evidence (qa-ios worktree): findings/evidence/triage/F26.json, F26.err; IOS-083/out.json, IOS-079/out.txt.
Extra acceptance criteria: on iOS, `record --json 2>/dev/null` stdout is a single JSON document; for a `.mp4` output
either pass `--codec=h264` with an MP4 container (e.g. record to `.mov` and remux with `avconvert`/AVFoundation) or
reject `.mp4` with a message suggesting `.mov` (ties in with C14's extension validation).
