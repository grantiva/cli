# Include xcodebuild's failure reason in MCP `grantiva_test` output

Severity: ux
Platforms: ios
Found by: IOS-F34 (matrix row IOS-112)
Binary: grantiva 2.0.1 (commit c8dc86d), Xcode 27.0, qa-ios-2 (iPhone 17, iOS 26.0)

## Expected
"Returns pass/fail counts and output" (grantiva_test tool description, Sources/GrantivaMCP/Tools/BuildTools.swift), so an
agent can see why tests failed.

## Actual
```
>> {"name": "grantiva_test", "arguments": {"scheme": "Landmarks", "simulator": "qa-ios-2"}}
<< {"content": [{"text": "Tests FAILED\nScheme: Landmarks\nDuration: 0.6s\nPassed: 0\nFailed: 0"}], "isError": true}
```
xcodebuild's actual message ("Scheme Landmarks is not currently configured for the test action") is dropped.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0
cat > /tmp/i17.json <<'J'
[{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}},
 {"method":"notifications/initialized","jsonrpc":"2.0"},
 {"method":"tools/call","params":{"name":"grantiva_test","arguments":{"scheme":"Landmarks","simulator":"qa-ios-2"}},"_timeout":600}]
J
python3 $QA/findings/evidence/IOS-mcp/client.py /tmp/i17.json /tmp/i17 /tmp/qa-ios-app -- grantiva mcp
grep -o 'Tests FAILED[^"]*' /tmp/i17/transcript.txt
```

## Evidence
- findings/evidence/IOS-mcp/phase7/transcript.txt (id 7)

## Suspected cause
Sources/GrantivaMCP/Tools/BuildTools.swift:236-246 formats only success, scheme, duration and counts. `TestResult.output`
(Sources/GrantivaCore/Build/XcodeBuildRunner.swift:168, filled at :103-110 from the failed command's message) is never
included.

## Acceptance criteria
- Re-running the repro: the result text includes the xcodebuild error line(s) (e.g. "Scheme Landmarks is not currently
  configured for the test action") and, for test failures, the failing test names.
- On failure, append the `error:` lines and the last ~40 lines of `output` (bounded, e.g. 4 KB); keep success output
  short.
- GrantivaMCPTests/BuildToolsTests: a fake runner returning `TestResult(success: false, output: "...error: Scheme X is not
  currently configured for the test action...")` yields text containing that error and `isError: true`.
