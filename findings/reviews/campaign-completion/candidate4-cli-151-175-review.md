# Candidate 4 CLI direct ordinals 151–175 review

Verdict: **APPROVED — 25/25 proposed passes are supported.**

This review uses flattened `batches[].rows[]` array position plus one from `cov5-cli/findings/evidence/cov5-cli/direct-row-batches.json`. Nested `row.ordinal` includes six handoff entries and is not the direct-row ordinal. The exact slice is CLI-161–164 and MCP-003/004/007/008/011/012/015/016/019/020/023/024/027/028/033/038/041/046/067/072/075.

I compared all 25 rows with the frozen matrix clauses, result links, verdicts, candidate identities, raw command or JSON-RPC transcripts, and assessments. Every executed capture binds manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` and its frozen artifacts. No capture timed out or reported cleanup failure.

CLI-161–164 support the installed runner-home stamp and layout, screen timeout and continuation wording with its contradiction check, both diff threshold definitions, and agreement among MCP help and the MCP/Android session documentation.

MCP-003 through MCP-028 cover the paired session-required operations. Their iOS and Android transcripts return `result.isError: true`, contain no JSON-RPC protocol error, give the required project-session start guidance, and continue by answering `tools/list` with 22 tools. The config-present and empty-directory fixtures remain distinct.

MCP-033, 038, and 041 prove platform-specific missing-config handling. MCP-033 names the correct missing file and init remedy on both platforms. MCP-038 reports both missing platform configs in its joint case. MCP-041 reports the in-scope iOS config failure while preserving the extra Android observation as excluded evidence. Each server remains responsive.

MCP-046 returns ordinary tool results for both platform probes, names the missing configuration and absence of a session, and continues serving requests. MCP-067 covers both missing-config branches and the separate config-with-no-screens branch, with `result.isError` and continued service. MCP-072 and MCP-075 return tool-level errors naming the missing configuration or captures, never JSON-RPC errors, and likewise continue.

Material gaps: **none found**.

The prior review labeled 151–175 actually covered flattened direct ordinals 145–169 because it selected nested ordinals. It is preserved as `candidate4-cli-direct145-169-review.historical.md`; this file supersedes it for the requested range.
