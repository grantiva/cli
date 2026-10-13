# Android B2-K01 current-round join review

The Android platform half is fully supported by genuine current-round runtime evidence plus exact runner source at `fd9d8e8d1cb109eda6116f4221da10257b9838e3`.

- `flow-wait-selector-contracts-rerun1/K01-selectors/` preserves the live line, summary line, flow JSON, and runner log for `tapOn: text="(Lake .*|.* Lake)", index=1`; the step succeeds and is never blank.
- `flow-wait-selector-contracts-rerun1/K01-point-taps/` preserves those same output surfaces for `tapOn: point="50%,50%"` and the other point forms; the flow succeeds.
- `flow-wait-selector-contracts-rerun1/K01-swipe-forms/` preserves percentage endpoints `swipe: start="80%, 50%" end="20%, 50%"` across live/summary/report/log output, alongside the other successful directional/anchored forms and postconditions.
- `CF-06-swipe-absolute/` fills the previously missing absolute endpoint leg. Live output, summary, `flow-000.json`, and `maestro-runner.log` all retain `swipe: start="300, 600" end="60, 600"`; it passes and the subsequent `Last swipe: left` assertion proves the gesture took effect.
- Exact runner `pkg/flow/describe_details_test.go:9-82` parses real YAML and semantically asserts indexed text taps, relative and absolute point taps, `doubleTapOn`/`longPressOn` point descriptions, percentage and absolute start/end swipes, numeric startX/startY/endX/endY, and nonempty unchanged scalar descriptions. This is the row's named unit-test clause rather than an inference from test names.

No Android output line ends in an empty `tapOn:`. The current runtime and source join covers every Android description form in the criterion. The explicit cross-platform identical-description clause still depends on joining the already owned iOS half; this review does not infer iOS behavior from Android evidence.
