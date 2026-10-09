# Send MCP `grantiva_type` keystrokes to the agent's `/wda/keys` endpoint

Severity: wrong-result
Platforms: ios
Found by: IOS-F31 (matrix row IOS-104)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-2 (iPhone 17, iOS 26.0)

## Expected
`grantiva_type {"text":" Yosemite"}` types into the focused field and returns the updated tree. Source: tool
description "Type text into the currently focused field on the device" (Sources/GrantivaMCP/Tools/UITools.swift:70).

## Actual
With the Name field focused (keyboard up) after `grantiva_tap {"x":360,"y":234}` on the edit screen:
```
>> {"name": "grantiva_type", "arguments": {"text": "Yosemite"}}
<< {"error": {"code": -32603, "message": "Internal error: Failed to type text exited with code 1"}}
```
A direct `POST /session/<id>/keys` to the agent returns 404; `POST /session/<id>/wda/keys` returns 200 and types.
`grantiva_type` never works on iOS.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-2
printf 'appId: com.kylebrowning.Landmarks\n---\n- launchApp\n- tapOn: "Deep Links"\n- tapOn: "Edit Landmark"\n- tapOn: "Name"\n' > /tmp/i06-edit.yaml
grantiva run --no-build --flow /tmp/i06-edit.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/i06.ready &
while [ ! -f /tmp/i06.ready ]; do sleep 0.2; done
f=$(ls -t /tmp/grantiva-sessions/*.grantiva | head -1); port=$(jq -r .port $f); sid=$(jq -r .sessionId $f)
curl -s -o /dev/null -w '%{http_code}\n' -XPOST localhost:$port/session/$sid/keys -d '{"value":["x"]}'      # 404
curl -s -o /dev/null -w '%{http_code}\n' -XPOST localhost:$port/session/$sid/wda/keys -d '{"value":["x"]}'  # 200
python3 $QA/findings/evidence/IOS-mcp/client.py $QA/findings/evidence/IOS-mcp/phase6.json /tmp/i06 /tmp/qa-ios-app -- grantiva mcp
grep -o 'Failed to type text[^"]*' /tmp/i06/transcript.txt; kill -INT %1
```

## Evidence
- findings/evidence/IOS-mcp/phase6/transcript.txt, IOS-mcp/phase1/transcript.txt (id 11)

## Suspected cause
Sources/GrantivaCore/WDA/WDAClient.swift:144 posts to `\(base)/session/\(sessionId)/keys`; GrantivaAgent (WDA) serves
`/session/{id}/wda/keys`.

## Acceptance criteria
- Re-running the repro: `grantiva_type` returns the updated tree and the field contains the typed text.
- typeText posts `{"value": [chars]}` to `/session/{id}/wda/keys` (keep a fallback to `/keys` only if a 404 is seen).
- GrantivaCoreTests/WDAClientTests: a stub server records the path and asserts `/wda/keys`; a non-200 error message names
  the HTTP status instead of " exited with code 1".
