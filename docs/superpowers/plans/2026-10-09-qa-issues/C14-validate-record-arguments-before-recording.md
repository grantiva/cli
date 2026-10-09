# Validate record arguments (--frames-at, --output extension) before recording

Severity: contract
Platforms: cli, ios
Found by: CLI-F14, CLI-F16 (matrix rows CLI-102)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
A bad `--frames-at` is a usage error (exit 64) before any recording; `--output` "Output video path" either works without
an extension or is rejected up front with a reason. Source: help: record (`--frames-at`, `--output`).

## Actual
`--frames-at a,b` records the whole duration, writes the video, then fails with exit 1 (triage: 4 MB video, 8 s):
```
Error: Invalid argument: --frames-at must contain non-negative integer milliseconds
```
`--output` without an extension writes a QuickTime file, then frame extraction fails with exit 1:
```
Error: Cannot Open
```

## Repro
```
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
time grantiva record --duration 5 --frames-at a,b --simulator "$udid" --output /tmp/c14.mp4; echo rc=$?
grantiva record --duration 2 --frames-at 1,5 --simulator "$udid" --output /tmp/c14-noext; echo rc=$?
```

## Evidence
- findings/evidence/cli/record/notes.txt

## Suspected cause
Sources/GrantivaCLI/RecordCommand.swift:88 records before `parseTimestamps()` runs at :93, and `parseTimestamps` throws
`GrantivaError.invalidArgument` (exit 1) rather than a `ValidationError`. With no extension, `AVURLAsset(url:)` at :138 /
`AVAssetImageGenerator` at :151 cannot open the file, and the AVFoundation error's description is printed bare.

## Acceptance criteria
- Re-running the repro: the first command fails in under a second with exit 64 and no video written; the second either
  succeeds (pass the file type to AVFoundation, or record to a temp `.mov` and move it) or fails before recording with
  "--output must end in .mov or .mp4".
- Move `--frames-at` parsing into `validate()`.
- GrantivaCLITests/RecordCommandTests: `--frames-at a,b` fails parsing with a ValidationError and the injected device's
  `recordVideo` is never called; an extensionless `--output` is accepted or rejected before `recordVideo`.
- `.mp4` is acceptable only if the written file is actually an MPEG-4 container: C13's iOS detail shows `.mp4` currently
  yields a QuickTime MOV, so either write real MP4 or reject/rename `.mp4` rather than leaving the wrong container.
- Update help: record `--output` to state the accepted extensions.
