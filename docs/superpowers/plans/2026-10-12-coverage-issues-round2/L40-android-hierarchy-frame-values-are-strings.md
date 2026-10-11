# On Android every hierarchy `frame` value is a JSON string (`"height" : "50"`), although docs/dump-hierarchy.md promises numbers

Severity: contract
Component: cli
Platforms: android (every Android JSON tree; logical). iOS passes (numbers since #194).
Rows: D2-31 [android]
Regresses/extends: extends K99 (docs/superpowers/plans/2026-10-11-coverage-issues/K99-hierarchy-json-raw-envelope.md, criterion 3; fixing PR #194). The #194 review ruled "frames become numbers in the shared parser"; the fix round converted iOS only ("Android still strings — small_tap_target reads both", findings/ledgers/2026-10-11-round2-fix-wave-ledger.md:69, :74). The round-2 docs now promise numbers for all platforms.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
docs/dump-hierarchy.md:30 (c65fc17): "`frame` is `{x, y, width, height}` with numbers (whole points as integers,
fractional ones as decimals) … On Android it is the UIAutomator2 tree with `type`, `platform` and `children`." The same
tree, with numeric frames, from `grantiva hierarchy --format json`, `grantiva runner dump-hierarchy --format json` and
MCP `grantiva_a11y_tree`.

## Actual
The three Android outputs agree with each other (root `{type, platform, children}`, boolean `enabled`/`visible`), but
every frame value is a string. findings/evidence/cov2-android/AND-054/01.out:13-18:
```
          "frame" : {
            "height" : "50",
            "width" : "411",
            "x" : "0",
            "y" : "0"
          },
```
The MCP tree (findings/evidence/cov2-android/MCP-S1/mcp-01/tree_deeplinks.json) has the same, escaped inside the tool
text: `\"height\" : \"50\"`, `\"height\" : \"16\"`.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l40
unset GRANTIVA_API_KEY
rm -rf /tmp/l40 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l40 && cd /tmp/l40/android
sed -i '' 's/^emulator: .*/emulator: fix-l40/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l40)
grantiva build install --device "$SERIAL" --no-launch
grantiva runner start --detach --device "$SERIAL"
grantiva hierarchy --format json | python3 -I -c '
import json,sys
def walk(n):
    f=n.get("frame")
    if f: yield f
    for c in n.get("children",[]): yield from walk(c)
fr=list(walk(json.load(sys.stdin))); print(len(fr), "frames;", sum(isinstance(v,str) for f in fr for v in f.values()), "string values")'
grantiva runner dump-hierarchy --format json | grep -m1 -A4 '"frame"'
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"qa","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_a11y_tree","arguments":{}}}' \
  | (cat; sleep 10) | grantiva mcp --project-dir /tmp/l40/android | grep -o '\\"height\\" : [^,]*' | head -2
grantiva runner stop; grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l40
```
Expected after the fix: `0 string values`, and `"height" : 50` (no quotes) in all three.

## Evidence
- findings/evidence/cov2-android/AND-054/01.out, h.json, commands.txt (`hierarchy --format json`)
- findings/evidence/cov2-android/MCP-S1/mcp-01/tree_deeplinks.json (`grantiva_a11y_tree`), MCP-S1/mcp-01/res_hier.json (`resources/read grantiva://hierarchy`)
- findings/evidence/cov2-android/D2-31/commands.txt (pointers)

## Suspected cause
- `Sources/GrantivaCore/Android/UIAutomator2HierarchyParser.swift:69-70`:
  `func dp(_ px: Int) -> String { String(Int((Double(px) / scale).rounded())) }` and
  `node["frame"] = ["x": dp(b.x), …]`. All three outputs go through this parser.
- `Tests/GrantivaCoreTests/UIAutomator2HierarchyParserTests.swift:39` pins the strings:
  `XCTAssertEqual(text["frame"] as? [String: String], ["x": "16", "y": "90", "width": "87", "height": "28"], …)`.
- `Sources/GrantivaMCP/Tools/UITools.swift:353-356` (`small_tap_target`) reads both forms via `frameNumber`, so it keeps
  working when the values become numbers.

## Acceptance criteria
- On Android, `hierarchy --format json`, `runner dump-hierarchy --format json` and `grantiva_a11y_tree` emit `frame`
  values as JSON integers (dp, rounded as today), identical across the three.
- `grantiva_a11y_check`'s `small_tap_target` results are unchanged for the same screen.
- docs/dump-hierarchy.md:30 needs no Android exception.
- GrantivaCoreTests/UIAutomator2HierarchyParserTests.swift:39 asserts `[String: Int]` (`["x": 16, "y": 90, "width": 87,
  "height": 28]`); add a GrantivaCLITests/HierarchyCommandTests case that an Android tree serialized by the command has no
  string-typed `frame` value.
