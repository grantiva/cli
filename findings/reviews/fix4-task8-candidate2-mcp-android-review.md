# Task 8 candidate 2 Android MCP review

Scope: completed raw evidence under `findings/evidence/round4-smoke-candidate2/05-mcp-android`. This was a bounded read-only review of retained provenance, MCP JSONL streams, acceptance data, and controller start/stop records. No live or device command was run.

## Verdicts

- **Specification/evidence verdict: APPROVED for the completed Android MCP phase.** L65 active and no-session contracts pass, and the ten concurrent transport pairs retain complete, unique, parseable large responses, small responses, and notifications.
- **Quality/integration verdict: APPROVED.** The phase and scoped runner stop both exited 0, the controller's post-stop session absence assertion completed, and no malformed or duplicate JSONL record was found.

## Frozen provenance

- `invocation/result.json` records the explicit Android invocation on `emulator-5580` / `smoke4-android`, session `fix4-8`, fresh candidate runner home, unset API environment, exactly ten pairs, candidate manifest SHA-256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`, and exit 0.
- `helper/provenance.json` records successful identity validation against clean CLI source `22055ff981ae1ffd5aaae69190d7af180f239162`, CLI binary SHA-256 `33c62e613703ddbd701a178028e099677b900deb003dceb02c74d86214555c37`, bundle manifest SHA-256 `da9adff34144cfe898e85d806b0a63e36be4b063b72ed902db8c8dc06efb6144`, runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, matching packaged/installed runner SHA-256 `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`, and `.15` install stamp. Platform, device, project, and API-key state match the invocation.

## L65 behavior

- The separate no-session client sends `grantiva_script {}`. Its raw response is an `isError` tool result naming the exact no-session project's `.grantiva/session.json`, gives the required start guidance, and says the one other-project/platform keep-alive session was ignored. This proves no-session precedence rather than falling through to missing-steps validation.
- On the active Android session, `grantiva_script {}` returns exactly `Error: Invalid argument: 'steps' is required.` with `isError: true`.
- `{"steps":"tap"}` returns exactly `Error: Invalid argument: 'steps' array is required.` with `isError: true`.
- `{"steps":[]}` succeeds and returns `Final hierarchy:`. The acceptance summary accurately marks the active exact, wrong-type, empty-array, and no-session checks.

## Concurrent transport evidence

- Both preflight hierarchy surfaces are already larger than the required boundary: 70,194 and 70,148 bytes.
- The active request stream contains IDs 1 through 49 exactly once, plus the initialization notification. Its response stream contains all 49 IDs exactly once in unconstrained completion order and ten `notifications/resources/updated` messages, for 59 valid JSON lines total. The MCP client result records `invalid: []`.
- For each of ten pairs, the retained resource response is 70,195 bytes and the tool hierarchy response is 70,149 bytes: 20 paired responses above 65,536 bytes. Each pair also has one `tools/list` response of 11,600 bytes and one successful script trigger; all ten small responses and all ten subscribed notifications arrive. Trigger replies are themselves large hierarchy-bearing responses, strengthening rather than weakening the framing exercise.
- The raw stream is 2,573,822 bytes and parses line by line. IDs are neither missing nor duplicated, and response ordering varies across pairs, demonstrating that the check did not assume serialized completion order.

## Scoped stop

`start/result.json` records a detached Android runner on exact device `emulator-5580`, PID `28614`, port `57453`, exit 0. After the MCP helper completed, `stop/result.json` records `grantiva runner stop --json` exit 0; its stdout reports status `stopped` for the same platform, serial/UDID, PID, and port. The retained executed controller then asserts that the project session file is absent before printing phase success. The evidence directory's invocation result is exit 0, so that terminal assertion passed.

This approval covers only the completed Android MCP phase. It does not review the pending helper correction batch, retry the earlier Android runner phase, or declare Task 8 complete.
