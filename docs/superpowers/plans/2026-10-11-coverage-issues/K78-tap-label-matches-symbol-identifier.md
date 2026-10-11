# MCP `grantiva_tap {label: "heart"}` taps the Favorites tab through its SF Symbol identifier

Severity: wrong-result
Component: mcp
Platforms: ios (iOS-only: WDA element lookup; no Android twin expected)
Rows: IOS-102 (ios); original brief I05 (~/.grantiva-qa/briefs/docs/superpowers/plans/2026-10-09-qa-issues/I05-mcp-tap-matches-accessibility-label.md); IOS-OBS-06 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

Triage note: brief I05's own criterion allows this ("`{"label":"heart"}` no longer matches (or matches only as a
fallback)", and "falling back to name"), and row B-I05.1 passed on the same transcript for that reason. Matrix row
IOS-102 (changed) asks for no match at all. The orchestrator should pick one contract; if the fallback stays, this
becomes a docs change (docs/mcp.md:50) and a matrix correction.

## Expected
Matrix IOS-102 (docs/mcp.md:50 "Tap on a UI element by accessibility label"): `{label: "Favorites"}` taps the tab and
returns the Favorites tree; `{label: "heart"}` does not match the tab, because `heart` is the tab image's symbol
name (its WDA `name`/identifier), not its label.

## Actual
MCP-LIVE1/run/transcript.txt:29-31, on the Favorites screen of a keep-alive session (cov-ios-1, 26.0):
```
>> {"method": "tools/call", "params": {"name": "grantiva_tap", "arguments": {"label": "heart"}}, "id": 13, "jsonrpc": "2.0"}
<< [1.1s] {"id": 13, "jsonrpc": "2.0", "result": {"content": [{"text": "Tapped on \"heart\". Updated hierarchy:\n{\n  \"children\" : [ …
```
No element on that screen has the label `heart`; the only match is the Favorites tab's identifier.
`{label: "Favorites"}` and `{x: 287, y: 822}` behave as expected.


**Absorbed from the iOS fix round.** Also IOS-OBS-06: on Edit Landmark, MCP cannot find the "Name" text field that the flow's `tapOn: "Name"` focuses, so the MCP lookup differs from the runner in both directions (evidence `findings/evidence/cov-ios/IOS-OBS-06/name-tap.txt`).

Result rows (`findings/cov-ios-results.md`):

> | IOS-OBS-06 | fail | IOS-OBS-06/name-tap.txt, B-I06.2/fix1-runner-start/transcript.txt | on Edit Landmark, MCP `grantiva_script {tap: "Name"}` fails `Element not found: "Name"` while the same screen's flow step `tapOn: "Name"` (19-park-edit, 03-edit) focuses the Name field: the MCP label lookup does not find the text field the runner does. Referenced by B-I06.2. |

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k78
unset GRANTIVA_API_KEY
rm -rf /tmp/k78 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k78 && cd /tmp/k78/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k78 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k78/ready &
while [ ! -f /tmp/k78/ready ]; do sleep 0.5; done
{ printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"fix","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"heart"}}}'
  sleep 30; } | grantiva mcp --project-dir "$PWD" | cut -c1-160
kill -INT %1; wait
grantiva simulator teardown --session-id fix-k78
```
Today: id 3 returns `Tapped on "heart". Updated hierarchy: …` (not `isError`).

## Evidence
- findings/evidence/cov-ios/MCP-LIVE1/run/transcript.txt (lines 29-31; the Favorites and x/y taps precede it),
  requests.json, commands.txt

## Suspected cause
`Sources/GrantivaCore/WDA/WDAClient.swift:79-111` (`tapByLabel`): the lookup loops over `["label", "name"]` (:88)
with a `predicate string` `<attribute> == "<label>"`; a 404 on `label` falls through to `name`, which in XCUITest is
the accessibility identifier (for an SF Symbol tab image, the symbol name). This fallback was added deliberately for
brief I05 (comment at :80-85). The same applies to `grantiva_script` `tap` if it shares this client call.

## Acceptance criteria
- Contract chosen and written in docs/mcp.md:50 (and the tool description in
  Sources/GrantivaMCP/Tools/UITools.swift): label only, or label then identifier.
- If label only: re-running the repro, id 3 returns `isError: true` with
  `Element not found: "heart". Run grantiva hierarchy (or the grantiva_a11y_tree MCP tool) to inspect the tree.`;
  id 2 still taps Favorites and returns its tree; `grantiva_script` `{"tap": "heart"}` fails the same way.
- If the fallback stays: the result says how it matched (for example `Tapped on "heart" (matched by identifier)`),
  docs/mcp.md says so, and matrix row IOS-102 is corrected.
- GrantivaCoreTests/WDAClientTests: with a stub server where `label == "heart"` returns 404 and `name == "heart"`
  returns an element, `tapByLabel("heart")` throws `elementNotFound` (label-only) or reports the identifier match
  (fallback).
