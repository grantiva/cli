# Match MCP `grantiva_tap` labels (and script `tap`) against the accessibility label

Severity: wrong-result
Platforms: ios
Found by: IOS-F30 (matrix rows IOS-102, IOS-107)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7, Xcode 27.0, qa-ios-2 (iPhone 17, iOS 26.0)

## Expected
`grantiva_tap {"label":"Favorites"}` taps the element whose accessibility label is "Favorites". Source: tool description
"Tap on a UI element by accessibility label or by coordinates" (Sources/GrantivaMCP/Tools/UITools.swift:32).

## Actual
The Favorites tab button has label `Favorites` and name `heart`:
```
>> {"name": "grantiva_tap", "arguments": {"label": "Favorites"}}
<< {"error": {"code": -32603, "message": "Internal error: Element not found: \"Favorites\". Run grantiva ui a11y to inspect the tree."}}
```
`{"label":"heart"}` taps it. Elements whose name equals their label ("Golden Gate Bridge") work. `grantiva_script` steps
`{tap:"Deep Links"}` and `{tap:"Edit Landmark"}` fail the same way. (The `grantiva ui a11y` hint is covered by C21.)

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios QA=/Users/kyle/Developer/grantiva-cli/.worktrees/qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0
grantiva build install --simulator qa-ios-2
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/i05.ready &
while [ ! -f /tmp/i05.ready ]; do sleep 0.2; done
cat > /tmp/i05.json <<'J'
[{"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}},
 {"method":"notifications/initialized","jsonrpc":"2.0"},
 {"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Favorites"}}}]
J
python3 $QA/findings/evidence/IOS-mcp/client.py /tmp/i05.json /tmp/i05 /tmp/qa-ios-app -- grantiva mcp
grep -o 'Element not found[^"]*' /tmp/i05/transcript.txt; kill -INT %1
```

## Evidence
- findings/evidence/IOS-mcp/phase1/transcript.txt (ids 7, 10), IOS-mcp/phase2, IOS-mcp/phase4 (id 2: `heart` works)

## Suspected cause
Sources/GrantivaCore/WDA/WDAClient.swift:82 finds the element with `{"using": "link text", "value": label}`, which WDA
matches against `wdName`, not `wdLabel`. Both UITools.swift:142 and ScriptTools.swift:83 call this `tapByLabel`.

## Acceptance criteria
- Re-running the repro: `{"label":"Favorites"}` taps the tab and returns the Favorites tree; `{"label":"heart"}` no
  longer matches (or matches only as a fallback).
- Use a predicate/class-chain locator on `label == $label` (escaping quotes), falling back to name; the same for script
  `tap`.
- GrantivaCoreTests/WDAClientTests: with a stub server, assert the find request uses a label-based strategy and escapes
  `"` in the label.
