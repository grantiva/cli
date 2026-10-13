# Task 8 candidate 3 MCP Android review

## Verdict

**Specification verdict: APPROVED.** The completed Android MCP phase satisfies L65 no-session precedence and exact active-session argument behavior, deterministic large-hierarchy setup, ten concurrent transport pairs, response/notification identity requirements, and exact owned runner start/stop.

**Evidence-quality verdict: APPROVED.** The frozen provenance, invocation metadata, helper acceptance, raw request/reply JSONL, and runner records agree. Preflight, runner start, helper invocation, and runner stop all exited zero; their stderr records are empty.

This approval covers the Android MCP phase only. Final candidate cleanup must still independently verify physical device/process/session/resource removal and protected-baseline preservation.

## Frozen identity and owned session

- The phase is bound to candidate manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, merged CLI `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, binary `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`, bundle manifest `b03433043f01599928e47b016e1dbd5b7efd3fbeddb47380db37b7711f31607d`, runner `ba9008f`/`9342b8a3`, and demo `84af7581`.
- Candidate identity preflight names owned serial `emulator-5580` and AVD `smoke4-c3-android`. The helper uses the isolated candidate runner home, project `mcp-android-project`, session `fix4-8-c3`, and API key unset.
- Runner start targets exactly `--platform android --device emulator-5580 --application-id com.kylebrowning.landmarks`. It records successful detached PID 67280, serial/UDID `emulator-5580`, and port 59540.

## L65 behavior

The no-session JSONL is parseable and contains the initialization response plus one tool response. The latter is an error with the exact no-active-session project path and states that one keep-alive session from another project or platform was ignored. This proves session lookup precedes missing-argument validation.

The active raw replies preserve:

- exact `Error: Invalid argument: 'steps' is required.`;
- exact `Error: Invalid argument: 'steps' array is required.`;
- successful empty `steps` with a final hierarchy.

Both MCP clients exit zero with no invalid protocol messages.

## Large response and transport evidence

The deterministic Android seed contains an explicit Landmarks tap. After applying it, the separately measured resource and hierarchy responses are 70,194 and 70,148 bytes, both greater than 65,536.

The active raw stream is valid JSON-RPC and contains 49 unique response IDs plus ten `notifications/resources/updated` messages. The stress portion has exactly ten request groups. Each group contributes the two designated hierarchy responses above 65,536 bytes and one tools-list response below 65,536 bytes, yielding the required 20 large and 10 small responses. It also produces one trigger response per group; those ten trigger replies contain final hierarchies and are additional large messages, rather than substitutes for the designated 20. All ten expected notifications arrive, and no ID is duplicated.

## Scoped runner cleanup

The controller validates the matching project session before stopping it. The exact-project stop exits zero and reports `status: stopped` for PID/runnerPID 67280, Android serial/UDID `emulator-5580`, application ID `com.kylebrowning.landmarks`, and port 59540. The phase controller then asserts that this project's session file is absent.

This is adequate per-phase cleanup evidence. It does not replace the final cleanup requirement to account for PID 67280, the owned emulator process/AVD, any campaign forwards or leases, and the protected pre-provision baselines.

## Scope

This was a read-only review of completed Android MCP artifacts. I did not execute a helper, test, build, process query, or device command, and I did not inspect or alter the pending lifecycle run.
