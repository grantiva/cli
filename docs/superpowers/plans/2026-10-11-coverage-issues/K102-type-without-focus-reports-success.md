# MCP `type` reports `typed "x"` when no field has focus and the keystrokes went nowhere

Severity: wrong-result
Component: mcp
Platforms: both (iOS ran the row; the Android `typeText` in UIAutomator2Client.swift:179-187 has the same no-focus gap, not run)
Rows: MCP-025 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
docs/mcp.md:52 defines `grantiva_type` as "Type text into the currently focused field", and `grantiva_script`'s
`type` action (docs/mcp.md:55) is the same action. When nothing is focused there is no field to type into, so the
call should fail as an `isError` result that names the missing focus (e.g. `No focused text field: tap a field
before typing "x".`), and a script should stop at that step the way it stops at an element that is not found.

## Actual
MCP-025 ran `grantiva_script` with
`[{tap: "Gesture Lab"}, {wait: 1}, {tap_xy: {x: 201, y: 495}}, {swipe: "up"}, {type: "x"}]`
(`findings/evidence/cov-ios/MCP-025/gesture-batch/transcript.txt:6`):
```
<< [5.0s @01:30:22] {"id": 2, "jsonrpc": "2.0", "result": {"content": [{"text": "Step 1: tapped \"Gesture Lab\"\nStep 2: waited 1.0s\nStep 3: tapped at (201, 495)\nStep 4: swiped up\nStep 5: typed \"x\"\n\nFinal hierarchy: …
```
The final tree has no text input of any kind: its element types are Application, Window, Other, NavigationBar,
Button and StaticText, with labels `Back`, `Gesture Lab`, `Taps: 1`, `Double taps: 0`, `Long presses: 0`,
`Last swipe: up`, `Last tap: center`, `Gesture pad`, `Landmarks` (parsed from stdout.raw, id 2). The result has no
`isError`.

`grantiva_type {text: "x"}` alone does the same (`findings/evidence/cov-ios/N-13/run/transcript.txt:47-49`,
on a screen with no focused field):
```
>> {"method": "tools/call", "params": {"name": "grantiva_type", "arguments": {"text": "x"}}, "id": 15, "jsonrpc": "2.0"}
<< [1.3s @00:52:01] {"id": 15, "jsonrpc": "2.0", "result": {"content": [{"text": "Typed \"x\". Updated hierarchy: …
```

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k102
unset GRANTIVA_API_KEY
rm -rf /tmp/k102 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k102 && cd /tmp/k102/ios   # main 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k102 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID"
grantiva runner start --simulator "$UDID" --detach; sleep 5
printf '%s\n' \
  '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_script","arguments":{"steps":[{"tap":"Deep Links"},{"wait":1},{"tap":"Gesture Lab"},{"wait":1},{"type":"x"}]}}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_type","arguments":{"text":"x"}}}' \
  | (cat; sleep 20) | grantiva mcp --platform ios --project-dir "$PWD" | cut -c1-200
grantiva runner stop; grantiva simulator delete --name "fix-k102 iPhone 17"
```
Today: id 1 ends `Step 5: typed "x"` and id 2 is `Typed "x". Updated hierarchy: …`, neither with `isError`.

## Evidence
- findings/evidence/cov-ios/MCP-025/gesture-batch/transcript.txt line 6 (script result), requests.json, stdout.raw (full tree)
- findings/evidence/cov-ios/N-13/run/transcript.txt lines 47-49 (`grantiva_type` alone)
- findings/cov-ios-results.md row MCP-025

## Suspected cause
- Sources/GrantivaCore/WDA/WDAClient.swift:145-157: `typeText` posts the characters to `/session/{id}/wda/keys`
  (falling back to `/keys`) and only checks for HTTP 200. The agent sends key events to the app whether or not
  anything is focused, and answers 200 either way; nothing asks for the focused element first.
- Sources/GrantivaCore/Android/UIAutomator2Client.swift:179-187: the Android `typeText` sends W3C key actions
  through `/actions`, also without a focus check (not exercised in this round).
- Sources/GrantivaMCP/Tools/UITools.swift:193-207 (`type`) and Sources/GrantivaMCP/Tools/ScriptTools.swift:108-110
  report success unconditionally after `typeText` returns.

Fix direction: before typing, ask the driver for the focused element (WDA `GET /session/{id}/element/active`,
UIAutomator2 the same W3C endpoint) and throw a `GrantivaError` naming the missing focus when there is none. Doing it
inside `DriverClient.typeText` covers both MCP paths and any other caller.

## Acceptance criteria
- With no focused field, `grantiva_type` returns `isError: true` with a text that says no field has focus and
  suggests tapping one; no keys are sent.
- In `grantiva_script`, a `type` step with no focus fails that step and stops the script, like an element-not-found
  `tap`, and the error names the step number.
- With a focused field (e.g. after `{tap: "Name"}` on Edit Landmark) both paths still type and report success.
- Unit tests in `GrantivaMCPTests`: `UIToolsTests.testTypeWithoutAFocusedElementIsAToolError` and
  `ScriptToolsTests.testTypeStepWithoutFocusStopsTheScript`, using a `DriverClient` stub whose focused-element lookup
  returns none; plus a `GrantivaCoreTests` WDAClient transport test asserting that `typeText` queries
  `element/active` before posting `wda/keys` and does not post when it answers "no such element".
