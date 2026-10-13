# iOS 26 Cancel timeout diagnosis

## Verdict

The new preferred-back predicate did not block and is not the observed timeout site. WDA completed both Cancel lookup predicates quickly, selected the same broad-label result the pre-fix selector would have selected, synthesized the tap, and then stalled while producing the updated hierarchy requested after every successful MCP tap.

This is a newly observed iOS 26 WDA/source-snapshot failure in this environment, following dismissal of the edit sheet while the Name field had focus. It is not safe to call it transient from one occurrence, but the retained evidence does not support reverting or widening the back-button fix.

## Evidence

The run is bound by `task8-back-priority-live-26/provenance.json` to CLI `6cad3f2b4081f0862cd0e93140eda11c2816b9ba`, release binary SHA-256 `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78`, iOS 26 simulator `DE2663B5-C24E-42DA-998D-20F7A80054B3`, runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, and demo source `84af7581b75134b0e417b254e4317d565f7b73c6`.

`mcp/requests.jsonl:13-14` sends `grantiva_tap Name` as request 12 and `grantiva_tap Cancel` as request 13. Reply 12 says `Tapped on "Name" (matched by placeholder)` and returns a Landmarks application hierarchy. That hierarchy contains:

- a visible `Cancel` `XCUIElementTypeButton` at `(20,66,69,36)`;
- a same-frame `Cancel` `XCUIElementTypeOther` wrapper;
- a `Name` text field with `placeholderValue: Name` and value `Golden Gate Bridge`;
- the `Edit Landmark` sheet and Landmarks application root.

Reply 13 exists and is a structured tool error: `The runner session's driver on port 9015 is not answering (The request timed out.)`. The MCP helper itself exits successfully and records all 13 replies, so this is a driver HTTP timeout rather than a lost MCP response or helper crash.

The device-specific WDA log at
`/private/tmp/grantiva-fix4-85-j1f5ksoz/runner-home/versions/1.1.28-grantiva.15+android-drivers-2/devices/DE2663B5-C24E-42DA-998D-20F7A80054B3/cache/wda-builds/sim-ios26.0-iphone-wda16.12.8-r1/devices/DE2663B5-C24E-42DA-998D-20F7A80054B3/runner.log`
shows the request phases:

1. At WDA elapsed 19.65–19.70 s, the preferred query completes. Because Cancel has no `BackButton` identifier, it yields no match.
2. At 19.71–19.76 s, the broad `label == "Cancel"` query completes.
3. WDA binds a Cancel Other, a Cancel Button, then the Cancel Other returned first by the broad query. At 19.92 s it starts `Tap "Cancel" Other`; by wall time 13:59:13.192 it has synthesized the event.
4. At 20.77 s WDA begins `Find the Application 'com.kylebrowning.Landmarks'` for the post-tap hierarchy. It requests the XML attributes at 13:59:13.762, then logs increasingly slow visibility reads and an invalid accessibility element. The retained log ends at 13:59:15.467 without completing the source response.

The implementation in `WDAClient.swift` performs the preferred predicate, then the unchanged broad label predicate, then clicks the first returned ID. `UITools.tap` subsequently sleeps 500 ms and fetches the updated hierarchy. Therefore the user-visible request can time out after a successful click if WDA's `/source` request stalls. That is exactly the sequence recorded here.

The new preferred query added roughly 0.05 seconds and had already returned before the broad query and click. The broad query chose the Cancel Other because it was first in WDA order; this is the preserved ordinary-label behavior and would also occur without the back-priority patch.

The additive screenshot `task8-back-priority-live-26/after-timeout.png` shows Settings after the runner was stopped. Because runner stop occurred before that screenshot, it does not prove that Settings was foreground during the Cancel request; it is consistent with Landmarks being terminated and the previously underlying app becoming visible.

The Settings result is still notable: reply 12 had definitively shown the Landmarks edit sheet and keyboard immediately before Cancel. A repeat should therefore capture the foreground screen before runner stop, rather than treating the later Settings image as irrelevant or as proof of the state at timeout.

The same exact CLI source completed the iOS 27 source-live campaign, including the Cancel control and the full back collision; `task8-back-priority-live-27/acceptance.json` records the overall pass, semantic-back win, independent hierarchy, screenshot, and coordinate control. That cross-version result narrows the failure toward the iOS 26 WDA/accessibility transition while leaving the iOS 26 failure unresolved.

## Classification and limits

Classification: environment/WDA iOS 26 hierarchy snapshot stall after a successful ordinary-label tap, possibly exposed by the focused text field, keyboard, and sheet dismissal transition. It is a novel live failure for this campaign and needs a controlled reproduction before deciding whether Grantiva needs hierarchy retry or timeout handling.

The evidence proves that the preferred predicate did not hang and that WDA accepted the tap. It does not prove whether the sheet dismissed visually, whether the keyboard transition caused the accessibility invalidation, or whether a later `/source` request would recover without restarting WDA.

## Narrow next diagnostic

On the same owned iOS 26 fixture in a fresh runner session, repeat only `Deep Links → Edit Landmark → Name → Cancel`. Retain the pre-Cancel hierarchy, then time and capture the four WDA operations independently: preferred Cancel lookup, broad Cancel lookup, element click, and post-click `/source`. Take an independent screenshot while the runner is still alive immediately after the click or timeout, followed by one separately timed `/source` retry.

That bounded capture will answer whether the tap dismisses the sheet and only the first transition-time snapshot hangs, whether all subsequent source requests remain wedged, or whether the broad wrapper click itself triggers a bad state. Do not change selector ranking from this evidence; if the independent click succeeds and only the first source fetch stalls, the next product investigation belongs in post-mutation hierarchy retry/timeout behavior rather than label selection.
