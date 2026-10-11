# `record --json` gives `video` as a relative path and every frame `path` as an absolute one

Severity: contract
Component: cli
Platforms: ios (seen on iOS; the report code is shared with Android, not tested there)
Rows: IOS-083 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix IOS-083 (README:340-341): valid JSON with the video path, per-frame `requestedMilliseconds` /
`actualMilliseconds` and `path`, `simulator`/`udid`. Paths in one report use one style, so a script can join or
compare them without knowing which field is which (`diff capture --json` reports relative `.grantiva/captures/…`
paths, MCP-063).

## Actual
json.out (`record --simulator <cov-ios-1> --duration 3 --frames-at 0,1000 --json`, exit 0):
```
      "actualMilliseconds" : 0,
      "path" : "\/private\/tmp\/…\/cov-ios\/ios\/.grantiva\/recordings\/recording-frames\/000000ms.png",
      "requestedMilliseconds" : 0
  …
  "requestedDurationSeconds" : 3,
  "simulator" : "cov-ios-1",
  "udid" : "A1C8EC2A-FB08-4EAC-A738-51E98D13CDBF",
  "video" : ".grantiva\/recordings\/recording.mov"
```
Text mode mixes them the same way (`Recording:` relative, `Frame report:` and frame lines absolute).

Secondary observation (not part of this defect): the frame requested at 1000 ms reports `actualMilliseconds: 0` on an
idle screen; worth a look when fixing record.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k85
unset GRANTIVA_API_KEY
rm -rf /tmp/k85 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k85 && cd /tmp/k85/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k85 iPhone 17" --runtime 26.0)
grantiva record --simulator "$UDID" --duration 3 --frames-at 0,1000 --json | jq -r '.video, .frames[].path'
grantiva record --simulator "$UDID" --duration 3 --frames-at 0,1000
grantiva simulator teardown --session-id fix-k85
```

## Evidence
- findings/evidence/cov-ios/IOS-083/commands.txt, json.out

## Suspected cause
`Sources/GrantivaCLI/RecordCommand.swift`: `video: outputPath` (:164) is the `--output` string as given (default
relative `.grantiva/recordings/recording.mov`), while frame paths come from
`URL(fileURLWithPath: outputPath)…appendingPathComponent(…).path` (:205-224), which resolves against the current
directory to an absolute path; `Frame report:` prints `reportURL.path` (:175), also absolute.

## Acceptance criteria
- Re-running the repro: `video` and every `frames[].path` use the same style. Pick one for the CLI (relative to the
  current directory when the output was given relatively, as `diff capture --json` does, or absolute everywhere) and
  apply it to the text output too.
- An absolute `--output` gives absolute paths throughout.
- GrantivaCLITests/RecordCommandTests: with an injected device and a relative `--output`, the encoded report's `video`
  and frame `path`s are all relative (or all absolute, per the chosen rule).
