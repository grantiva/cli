# Android wait screens and remaining X-row join review

## Android screens complement

`wait-screens-complement-rerun2/` is valid. Both plain and JSON **`diff capture --no-build`** commands exit 0; all configured screens and exact-selector actions pass. Live and summary text agree on `Wait 3s` and `Wait 1.5s`, no `evalScript` appears, and JSON uses those same actions. This supports B2-K90-a. It supports only the diff-capture half of B3-L18 `[android]`: the retained commands do not exercise the row's separately required `run --no-build` screens blocks. No other current-round Android artifact found by the review contains the 1.5-second run surface, so B3-L18 remains partial.

B-C09.2 `[android]` is also supported when joined with exact candidate and runner source. `FlowGeneratorTests.testWaitStepSleepsUnconditionally` pins a generated runner `wait` for config `wait:` while separate settle steps remain `waitForAnimationToEnd`. Runner `WaitStep` is a distinct fixed-duration construct, and `executeWait` uses a timer for the requested milliseconds rather than animation settling.

The JSON duration `2.999` for `Wait 3s` does not establish that the wait returned early. Runner execution blocks on a 3000 ms timer, then separately records `time.Since(stepStart).Milliseconds()` and exports seconds at millisecond precision; the plain renderer rounds the same observation to `3.0s`. The 1.5-second sibling records exactly `1.5`. B-C09.1 asks whether the step takes at least three seconds, not whether a truncated/quantized duration field is numerically `>= 3.000`. The runtime success plus direct timer semantics support **pass**, while the wrapper's strict JSON-duration assertion is an invalid proxy and should remain disclosed. If the campaign instead binds the row to reported JSON duration, it would be a 1 ms literal reporting failure, but that is not the written criterion.

## X-007

Current evidence does not fully meet the exact paired input. iOS attempt 46 is paired text/JSON but has two screens, not five. iOS attempt 39 (`appfile-capture-five.out`) is a valid five-screen JSON capture. Android has a five-screen JSON capture at `flow-contracts-bulk-exact-rerun3/K17-capture-json/stdout.log` and five-screen text at `AND-027-065diff-exact-rerun1/AND-065-diff/stdout.log`. The decoded JSON common keys and screen-item shapes agree; Android adds the documented `emulator` object alongside `simulator`, and text uses `Emulator` where iOS uses `Simulator`. The remaining exact gap is a current five-screen iOS **text** capture paired to the JSON input (or an already retained equivalent that can be indexed). X-007 therefore remains partial; the available shape comparison does not justify silently substituting the two-screen pair.

## X-018

iOS attempt 64 `second-run.err` and Android `AND-063/01.err` support X-018. Both are real second-run ownership refusals and name the owner CLI pid, age, runner pid, `--keep-alive`, force-teardown remedy, and unique-device remedy. The only semantic substitutions are `Simulator`/`Emulator`, UDID/serial, and `simulator ensure`/`emulator ensure`. Their surrounding artifacts establish an existing owned keep-alive session rather than a fabricated error. This is a supported pass for the explicit cross-platform message-structure criterion.

## X-021

The current successful response pairs support X-021. iOS attempt 16c supplies tap/swipe, and attempt 25 supplies type/tree; Android `MCP-type-exact/mcp/` supplies `tap-name.json`, `swipe-up.json`, `type-renamed.json`, and `tree-final.json`. Every response uses the same JSON-RPC result envelope and one text content block. Tap, swipe, and type prefix a success sentence followed by `Updated hierarchy:` and a JSON tree; tree returns the same JSON tree form directly. Parsed trees on both platforms use the same recursive node/children representation and typed frame/state fields. Platform element names, geometry, and screen state differ as expected and are not schema differences. X-021 is supported.
