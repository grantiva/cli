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
