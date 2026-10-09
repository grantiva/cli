# Make the default `--logs` predicate match the app's process on a simulator

Severity: wrong-result
Platforms: ios
Found by: IOS-F19 (matrix row IOS-061)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-1 (iPhone 17, iOS 26.0)

## Expected
`--logs` interleaves the app's log lines as `[log] ...`. Source: help: run `--logs` ("On iOS the filter defaults to lines
whose subsystem or process matches the app's bundle ID", Sources/GrantivaCLI/RunCommand.swift:23); README.

## Actual
Flow 08 with `--logs` streams exactly two lines, both noise:
```
Streaming simulator logs (predicate: subsystem BEGINSWITH "com.kylebrowning.Landmarks" OR processImagePath CONTAINS "com.kylebrowning.Landmarks")
[log] getpwuid_r did not find a match for uid 501
[log] Filtering the log data using "subsystem BEGINSWITH "com.kylebrowning.Landmarks" OR processImagePath CONTAINS "com.kylebrowning.Landmarks""
```
The same run with `--logs-predicate 'process == "Landmarks"'` streams 913 `[log]` lines from `Landmarks[pid]`.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-1 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-1
grantiva run --no-build --flow .maestro/08-caching.yaml --simulator qa-ios-1 --logs 2>&1 | grep -c '^\[log\]'          # 2
grantiva run --no-build --flow .maestro/08-caching.yaml --simulator qa-ios-1 \
  --logs-predicate 'process == "Landmarks"' 2>&1 | grep -c '^\[log\]'                                                   # ~900
```

## Evidence
- findings/evidence/triage/F19-logs.err, F19-proc.err
- findings/evidence/IOS-061/err.txt, IOS-061/proc-err.txt

## Suspected cause
Sources/GrantivaCore/Runner/LogStreamer.swift:181-183 builds
`subsystem BEGINSWITH "<bundle>" OR processImagePath CONTAINS "<bundle>"`, used by IOSPlatform.logStream
(Sources/GrantivaCore/Platform/IOSPlatform.swift:102). On a simulator the image path is `.../Landmarks.app/Landmarks`, which
never contains the bundle ID, so only apps that log under a subsystem named after their bundle ID are matched.

## Acceptance criteria
- Re-running the repro: the default `--logs` run streams the app's lines (hundreds for flow 08), and no
  `getpwuid_r`/"Filtering the log data" banner lines are prefixed `[log]`.
- The default predicate also matches the app's executable: read `CFBundleExecutable` from the installed/built app (or
  `simctl get_app_container ... app`) and add `OR process == "<executable>"` (or `processImagePath CONTAINS
  "<App>.app/"`). Update the help text to say what it matches.
- GrantivaCoreTests/LogStreamerTests: `defaultLogPredicate(forBundleID:executable:)` includes the executable clause, and
  the simctl banner lines are filtered out of the stream.
