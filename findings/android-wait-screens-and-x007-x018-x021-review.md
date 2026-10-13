# Android wait screens and remaining X-row join review

## Android screens complement

`wait-screens-complement-rerun2/` is valid. Both plain and JSON **`diff capture --no-build`** commands exit 0; all configured screens and exact-selector actions pass. Live and summary text agree on `Wait 3s` and `Wait 1.5s`, no `evalScript` appears, and JSON uses those same actions. This supports B2-K90-a. `B3-L18-run-wait15-complement-rerun1` supplies the missing `run --platform android --device emulator-5554 --no-build` screens surface: exit 0, `Wait 3s`, `Wait 1.5s`, all exact markers, and no `evalScript`. Joined with diff text/JSON and exact source strings, B3-L18 `[android]` is fully supported.

B-C09.2 `[android]` is also supported when joined with exact candidate and runner source. `FlowGeneratorTests.testWaitStepSleepsUnconditionally` pins a generated runner `wait` for config `wait:` while separate settle steps remain `waitForAnimationToEnd`. Runner `WaitStep` is a distinct fixed-duration construct, and `executeWait` uses a timer for the requested milliseconds rather than animation settling.

The JSON duration `2.999` for `Wait 3s` does not establish that the wait returned early. Runner execution blocks on a 3000 ms timer, then separately records `time.Since(stepStart).Milliseconds()` and exports seconds at millisecond precision; the plain renderer rounds the same observation to `3.0s`. The 1.5-second sibling records exactly `1.5`. B-C09.1 asks whether the step takes at least three seconds, not whether a truncated/quantized duration field is numerically `>= 3.000`. The runtime success plus direct timer semantics support **pass**, while the wrapper's strict JSON-duration assertion is an invalid proxy and should remain disclosed. If the campaign instead binds the row to reported JSON duration, it would be a 1 ms literal reporting failure, but that is not the written criterion.

## X-007

X-007 is now supported. iOS attempt 92 is a current plain five-screen capture of the same stock screen set as attempt 39's five-screen JSON capture: Home, Favorites, Deep Links, Lakes, and Detail, with matching action lists. Android has the corresponding five-screen JSON capture at `flow-contracts-bulk-exact-rerun3/K17-capture-json/stdout.log` and plain text at `AND-027-065diff-exact-rerun1/AND-065-diff/stdout.log`. Both text modes render the same screen/action hierarchy and device/display summary, substituting `Simulator` on iOS for `Emulator` on Android. The decoded JSON common keys and screen-item shapes agree; Android adds the documented `emulator` object alongside `simulator`. Dynamic duration, timestamp, byte size, device identity, and geometry values differ without changing shape. These are genuine current captures and complete the exact five-screen text/JSON comparison.

## X-018

iOS attempt 64 `second-run.err` and Android `AND-063/01.err` support X-018. Both are real second-run ownership refusals and name the owner CLI pid, age, runner pid, `--keep-alive`, force-teardown remedy, and unique-device remedy. The only semantic substitutions are `Simulator`/`Emulator`, UDID/serial, and `simulator ensure`/`emulator ensure`. Their surrounding artifacts establish an existing owned keep-alive session rather than a fabricated error. This is a supported pass for the explicit cross-platform message-structure criterion.

## X-021

The current successful response pairs support X-021. iOS attempt 16c supplies tap/swipe, and attempt 25 supplies type/tree; Android `MCP-type-exact/mcp/` supplies `tap-name.json`, `swipe-up.json`, `type-renamed.json`, and `tree-final.json`. Every response uses the same JSON-RPC result envelope and one text content block. Tap, swipe, and type prefix a success sentence followed by `Updated hierarchy:` and a JSON tree; tree returns the same JSON tree form directly. Parsed trees on both platforms use the same recursive node/children representation and typed frame/state fields. Platform element names, geometry, and screen state differ as expected and are not schema differences. X-021 is supported.
