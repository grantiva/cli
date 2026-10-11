# `grantiva hierarchy --format json` on iOS prints the raw driver envelope `{"value": …, "sessionId": …}` instead of the tree

Severity: contract
Component: cli
Platforms: ios (iOS-only: the Android half of X-011 passed with an unwrapped `{type, platform, children}` tree)
Rows: X-011 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix X-011 (docs/dump-hierarchy.md:27-30; docs/android.md:105-106): the XML root and the JSON structure are
documented per platform. The XML is "unwrapped from WDA's `{"value": "…"}` envelope" (docs/dump-hierarchy.md:29);
the JSON should be unwrapped the same way and match what `grantiva runner dump-hierarchy --format json` and
`grantiva_a11y_tree` print for the same screen (a tree object with `children`).

## Actual
IOS-049/format-json.out (keep-alive session on the Landmarks list; output parsed and its top-level keys printed):
```
exit=0
dict ['value', 'sessionId']
```
`grantiva hierarchy --json` gives the identical envelope (IOS-050). `runner dump-hierarchy --format json`
(IOS-085/f-json.out) prints the unwrapped tree:
```
{
  "children" : [
    {
      "children" : [
```
Inside the envelope, frames and flags are strings (`'isVisible': '1'`, `'height': '44'`); `grantiva_a11y_tree`
(MCP-017) also uses string frame values, so that part is shared and may be tracked separately.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k99
unset GRANTIVA_API_KEY
rm -rf /tmp/k99 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k99 && cd /tmp/k99/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k99 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml --keep-alive --ready-file /tmp/k99/ready &
while [ ! -f /tmp/k99/ready ]; do sleep 0.5; done
grantiva hierarchy --format json | jq -c 'keys'                    # today: ["sessionId","value"]
grantiva runner dump-hierarchy --format json | jq -c 'keys'        # the unwrapped tree
kill -INT %1; wait
grantiva simulator teardown --session-id fix-k99
```

## Evidence
- findings/evidence/cov-ios/IOS-049/commands.txt, format-json.out
- findings/evidence/cov-ios/IOS-050/ (`--json` identical), IOS-048/hierarchy-xml.out (XML, unwrapped)
- findings/evidence/cov-ios/IOS-085/f-json.out, json.out (runner dump-hierarchy JSON)
- (The X-011 evidence directory in the iOS slice is empty; the rows above are its sources.)

## Suspected cause
`Sources/GrantivaCLI/HierarchyCommand.swift:84-120`: for JSON it requests `/source?format=json` (:88) and, because
only the XML branch is unwrapped (:114-116, `unwrapWDASource`), writes the response body verbatim (:117-119).
`runner dump-hierarchy` instead parses the XML into a tree (`Sources/GrantivaCLI/DriverCommand.swift:816-821`), and
the Android branch (`runAndroid`, HierarchyCommand.swift:125-140) serialises `client.hierarchy()`.

## Acceptance criteria
- Re-running the repro: `grantiva hierarchy --format json` (and `--json`) prints a JSON object without `value` /
  `sessionId` wrappers, with the same top-level shape as `grantiva runner dump-hierarchy --format json` for the same
  screen (or as `grantiva_a11y_tree`; pick one shape for all three and document it in docs/dump-hierarchy.md:30).
- XML output unchanged.
- Numeric frame values and booleans are numbers/booleans, or the docs say they are strings (coordinate with the
  Android X-011 note and MCP-017).
- GrantivaCLITests/HierarchyCommandTests: a stub agent returning `{"value": {…tree…}, "sessionId": "x"}` for
  `/source?format=json` produces the unwrapped tree on stdout.
