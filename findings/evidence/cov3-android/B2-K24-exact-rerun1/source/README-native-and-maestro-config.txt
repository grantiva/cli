### Screens

Each screen has a `name` and a `path`. The path describes how to navigate there:

- `launch` — screenshot right after app launch. On Android the first screen first waits (up to 10 s, then
  continues) until an element with text is on screen inside the app's own content view, so the capture is never the
  empty window a cold start shows before the app draws; when the app has already drawn this is a single lookup
- `- tap: "Label"` — tap a button or element by accessibility label
- `- swipe: up` — swipe in a direction (`up`, `down`, `left`, `right`, any case); any other value is a config error
- `- type: "text"` — type text into the focused field
- `- wait: 2` — wait N seconds (always the full N seconds, even if the screen is already still)
- `- assert_visible: "Label"` — verify an element is visible (fails if not)
- `- assert_not_visible: "Label"` — verify an element is hidden
- `- run_flow: "path/to/flow.yaml"` — include steps from another YAML file

A label is a case-insensitive regular expression matched against an element's whole text, on iOS and Android alike:
`tap: "Open"` matches an element whose text is "Open" or "open", not "Talk · Open" (write `.*Open.*` to match part of
the text). `tap`, `assert_visible`, and `assert_not_visible` also take `{text: "Landmarks", exact: true}` to require
the element's text to equal the label exactly as written, or `{id: "clock"}` to select by identifier instead of text
(the accessibility identifier on iOS, the resource id or Compose test tag on Android). A mapping names `text` or `id`,
not both; a step that does not decode is a config error naming the file, line and key, and what the key takes.

Grantiva navigates to each screen in order, captures a screenshot, then moves to the next. After every `tap`, `swipe`, `type`,
and `run_flow`, and before every screenshot, it waits (up to 5 s) for the screen to stop changing, so a capture never shows
the screen it is leaving. Unknown keys in the config file are reported as warnings with their line number.

### Maestro Compatibility

Grantiva can read [Maestro](https://maestro.mobile.dev) flow files as a drop-in replacement. If you have existing Maestro flows, Grantiva will auto-detect and parse them — no rewrite needed.

Alerts on iOS: a `launchApp` pre-grants the app's permissions on the simulator, and GrantivaAgent auto-accepts only system alerts that appear during the flow (notifications, tracking, local network, Bluetooth and other prompts the simulator cannot pre-grant), so they don't block it. Your app's own alerts ("Discard changes?") are left alone: they stay up until a flow step answers them, including in `runFlow` subflows.

Place your flows in a `.maestro/` directory, or write `grantiva.yml` in Maestro format:

```yaml
appId: com.example.myapp
---
- launchApp
- tapOn: "Sign In"
- inputText: "user@example.com"
- takeScreenshot: "Login"
- tapOn: "Submit"
- assertVisible: "Welcome"
- takeScreenshot: "Welcome"
```

Each `takeScreenshot` becomes a named screen capture point. Commands between screenshots become navigation steps. Supported Maestro commands: `tapOn`, `doubleTapOn`, `longPressOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe` (`direction:`, optionally with `from:`, or `start:`/`end:` as `"x%, y%"`, plus `duration:`), `scroll`, `scrollUntilVisible` (kept as a scroll, with its `direction:` and `timeout:`), `runFlow` (a file, `{file: ...}`, or inline `{commands: [...]}`; a `takeScreenshot` inside a sub-flow is a screen like one in the parent), `extendedWaitUntil` (`visible:` or `notVisible:`, with its `timeout:` kept), `waitForAnimationToEnd`, `launchApp`, `stopApp`, `killApp`, and `takeScreenshot`. `grantiva-android.yml` may be written in the same Maestro format; its `appId:` is the application ID. Selectors accept a string or `{text: ...}` (matches text) or `{id: ...}` (matches the accessibility identifier). Any other command (`back`, scripting, permissions, etc.) is rejected before the run starts, with an error naming the file and line: `grantiva.yml:5: unsupported Maestro command 'back'`. Flows run with `grantiva run --flow` go to the runner as written and are not limited to this list.

The app a `run --flow` run launches is chosen in this order: `--bundle-id` / `--application-id`, then `bundle_id` / `application_id` in the config file, then the ID read from `--app-file`, then the flow's own `appId:` header (ignored when it is a `${VARIABLE}` reference), then project detection (iOS). Project detection runs only when building: with `--no-build` it is skipped, so pass `--bundle-id` or give the flow a literal `appId:`.

