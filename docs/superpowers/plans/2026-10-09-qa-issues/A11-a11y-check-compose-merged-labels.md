# Treat Compose buttons labelled by merged descendant text as labelled in `grantiva_a11y_check`

Severity: ux
Platforms: android
Found by: AND-F18 (matrix rows AND-099)
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
`missing_label` flags only controls TalkBack cannot name. Source: docs/android.md and CHANGELOG Unreleased (the check keys
on `class`, `content-desc`, `clickable`; 48 dp minimum).

## Actual
On the Deep Links screen: 12 violations, a `missing_label` and a `small_tap_target` for each of the six buttons:
```
"rule" : "missing_label", "type" : "android.widget.Button",
"message" : "Interactive element of type android.widget.Button has no accessibility label or name."
```
The 40 dp height is real; the labels are not missing. The hierarchy shows each Compose button as a clickable parent
`android.view.View` holding a `TextView text="Caching Demo"` and a non-clickable, empty `android.widget.Button` sibling:
```
<android.view.View ... clickable="true" focusable="true" bounds="[42,359][1038,485]">
  <android.widget.TextView ... text="Caching Demo" clickable="false" .../>
  <android.widget.Button ... text="" clickable="false" focusable="false" bounds="[42,369][1038,474]"/>
```
TalkBack reads the parent with the merged text "Caching Demo".

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva runner start --device emulator-5554 --detach
# MCP over stdio: initialize, then tap the Deep Links tab and run the check
{ echo '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"qa","version":"0"}}}'
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"grantiva_tap","arguments":{"label":"Deep Links"}}}'
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"grantiva_a11y_check","arguments":{}}}'; sleep 8; } \
  | grantiva mcp | grep -o 'missing_label' | wc -l          # 6
grantiva runner stop
```

## Evidence
- findings/evidence/AND-093/session1.log (a11y_check output), AND-061/hierarchy-immediate.xml (lines 54-57)

## Suspected cause
Sources/GrantivaMCP/Tools/UITools.swift:251-254 (`isInteractive`) treats any `android.widget.Button` as interactive by
class even when `clickable="false"`, and :291-293 exempts only non-widget containers with descendant labels, so the
empty Button node is checked on its own `text`/`content-desc` (UITools.swift:238-242 lists the widget classes).

## Acceptance criteria
- Re-running the repro: no `missing_label` on the Deep Links buttons; `small_tap_target` may stay.
- On Android, a widget-class node that is not clickable/focusable is skipped when a clickable ancestor carries a label
  (own or descendant text), i.e. the check evaluates the node TalkBack focuses, not the inner semantic stub.
- A genuinely unlabelled clickable Button (no text anywhere in its focus group) is still flagged.
- GrantivaMCPTests (new UIToolsTests): the Deep Links XML fragment above yields no `missing_label`; a clickable
  `android.widget.ImageButton` with empty `content-desc` and no descendants yields one.
