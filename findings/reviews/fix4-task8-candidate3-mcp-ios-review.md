# Task 8 candidate 3 MCP iOS review

## Verdict

**Specification verdict: APPROVED.** The completed candidate 3 iOS MCP phase satisfies the required L65 session/error behavior, full L66 selector behavior including the repaired two-level same-label back collision, deterministic large hierarchy setup, concurrent transport stress, retry/error path, and exact-session stop.

**Evidence-quality verdict: APPROVED.** Invocation, helper acceptance, raw JSONL requests/replies, retry HTTP trace, identity provenance, and runner start/stop records agree. All three MCP clients exited zero with no invalid messages, and the phase invocation and exact stop both exited zero.

This is one phase of candidate 3 smoke. Physical owned-device cleanup and final process/baseline verification remain part of the final cleanup gate.

## Identity and execution binding

- The recorded preflight and helper provenance bind frozen manifest SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`, merged CLI HEAD `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, QA binary `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`, bundle manifest `b03433043f01599928e47b016e1dbd5b7efd3fbeddb47380db37b7711f31607d`, runner `ba9008f`/`9342b8a3`, and demo `84af7581` with app manifest `b9619e1d`.
- The phase names owned UUID `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`, project `mcp-ios-project`, isolated runner home, session `fix4-8-c3`, and API key unset throughout.
- Runner start targets only that UUID and bundle ID `com.kylebrowning.Landmarks`. It records owned PID 62796, iOS platform, the same UUID, and successful detached status.

## L65 and L66 behavior

The no-session client returns the exact no-active-session error before argument validation and explicitly reports that one keep-alive session from another project/platform was ignored. The active raw replies retain:

- exact missing-`steps` and wrong-type errors;
- successful empty steps with a final hierarchy;
- the exact unknown-selector error;
- ordinary label selection, identifier annotation for `heart`, placeholder annotation for `Name`, successful `Cancel`, and correctly decoded quoted `Mount "Denali"`;
- script-step identifier fallback and application-root exclusion;
- a live hierarchy containing the Mountains BackButton plus selected same-labelled Landmarks tab, followed by Mountains back to the collision hierarchy and semantic Landmarks back to a root containing Golden Gate Bridge;
- a fresh hierarchy after semantic back and a working coordinate tap derived from the live Favorites frame.

The raw replies support the helper's `applicationRootExcluded`, `quotedLabel`, and `backButtonWins` assertions. In particular, the resulting semantic-back reply and subsequent independent tree both contain Golden Gate Bridge, so the repaired L85 path is exercised inside the full candidate smoke rather than inferred from the earlier focused source run.

## Transport and retry

The deterministic iOS seed contains one explicit operation and is applied before transport measurement. The two preflight hierarchy responses are 212,617 and 212,571 bytes, both above 65,536.

The active JSONL is parseable JSON-RPC throughout. Its stress section contains ten pairs, each with two designated large responses, one small tools-list response, and one trigger response. Raw accounting confirms the required 20 designated large responses, 10 small responses, 10 `notifications/resources/updated` messages, and unique response IDs. The additional ten trigger replies also carry final hierarchies; they do not substitute for the designated 20-large/10-small checks.

The retry client returns the required application-not-running error after the helper terminates the exact app. `retry-http.json` shows two element lookups returning HTTP 400, separated by about 1.03 seconds, with successful status probes before each. The original session bytes are restored in `finally`, so the injected proxy port does not leak into the controller's subsequent stop.

## Scoped runner cleanup

The controller stops only the matching iOS project after validating its platform and UUID. Stop exits zero and reports `status: stopped` for PID/runnerPID 62796, the exact UUID, bundle ID, and port 8274. The controller then asserts that this project's session file is absent. This is adequate phase cleanup evidence; the eventual final cleanup review must still independently account for recorded owned PIDs and protected resources across the whole candidate campaign.

## Scope

This was a read-only review of the completed iOS MCP phase. I did not run a helper, build or test code, issue device commands, inspect the concurrently active Android phase, or mutate any evidence.
