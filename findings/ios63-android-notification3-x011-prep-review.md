# iOS attempt63, Android notification-v3, and X-011 preparation review

## iOS attempt63

All five new grades are supported.

- **B-A05.2 [ios] / IOS-136:** `flow10-active-proof.txt` records the flow-10 PID still live after its first scroll. The concurrent exact `--frames-at 500,1500` recording exits 0 and reports actual times 487 and 1493 ms, with both PNGs retained. Flow 10 itself exits 0. This directly resolves the earlier zero-timestamp concern.
- **B2-K84 [ios]:** the 5000 ms request against duration 2 exits 64 in 0.010559 s with the exact bounds error. The pre/post SHA-256 of the prior default recording is identical, proving validation occurred before replacement. The equal boundary 2000 ms is accepted and records successfully. Exact-head `RecordCommandTests.testFramesAtPastTheDurationIsAUsageErrorBeforeRecording` asserts both rejection and equality acceptance, while the adjacent held-recording test covers a valid timestamp past the raw final sample.
- **B2-K85 [ios]:** relative text and JSON keep the video/report/frame paths relative; absolute text and JSON keep all paths absolute. `project-recordings/` plus the top-level absolute artifacts retain every referenced MOV, JSON, and PNG. Exact-head K85 tests at `RecordCommandTests.swift:441-483` assert the same relative/absolute rule.
- **D2-12 [ios]:** the K84 invalid request and K85 four path variants jointly satisfy both clauses without inference.

Attempt63 also corroborates X-010 with the requested 3-second, 0/1000 ms JSON form, but X-010 was already supported by the prior exact iOS/Android pair; no duplicate grade is needed.

## Android notification-v3

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K57-D245-notifications-rerun3/`.

The corrected transcript closes both B2-K57 `[android]` and D2-45 `[android]` runtime clauses:

1. Failed tap before subscription: no notification.
2. Subscribe: succeeds.
3. Successful `Gesture Lab` tap: exactly one hierarchy-updated notification, before the response.
4. Rejected empty tap: no notification.
5. Script: step 1 `tap_xy` runs and mutates UI, step 2 fails; exactly one notification is emitted, and the response explicitly lists the successful first step.
6. Unsubscribe: succeeds.
7. Successful post-unsubscribe coordinate tap: no notification.

There are exactly two notification lines in the transcript, both in the two subscribed mutation cases. The MCP server remains responsive, streams only JSON, and all client/run/stop wrapper components exit 0. The v2 limitation is resolved rather than overwritten.

The source-test clause is also present at exact candidate `8f2cff67`: `Tests/GrantivaMCPTests/HierarchyNotificationTests.swift` asserts no notification without subscription, no notification for rejected/failed calls, one after successful tap, none after unsubscribe, and one when a script mutates UI before a later step fails. This is a semantic assertion inspection, not a claim of a new test execution.

## X-011 comparison conditions

iOS attempt61 is ready for pairing: a live keep-alive session on the Landmarks list preserves both `list.xml` and `list.json`. The XML root is `XCUIElementTypeApplication` with point-valued numeric `x/y/width/height`; JSON preserves the documented iOS hierarchy structure with numeric `frame` members.

The Android counterpart must preserve the same live list screen in both XML and JSON. Review should compare documented structure rather than byte equality:

- Android XML should have the platform root/type and dp-valued bounds documented in `docs/android.md`.
- Android JSON should retain the shared tree fields (`type`, children, visibility/enabled state where supplied, and numeric complete frames) with Android platform identity.
- Both forms must come from the same live keep-alive list state; a generic resource-list response or a different screen is insufficient.

Final X-011 verdict is deferred until that Android raw is complete.
