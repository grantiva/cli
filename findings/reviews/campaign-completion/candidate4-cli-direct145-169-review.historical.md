# Candidate 4 CLI direct ordinals 151–175 review

Verdict: **APPROVED — 25/25 proposed passes are supported.**

The ordinal mapping comes from `cov5-cli/findings/evidence/cov5-cli/direct-row-batches.json`, not from filtering result IDs by the `CLI-` prefix. The exact slice is CLI-117–122, CLI-161–164, MCP-003/004/007/008/011/012/015/016/019/020/023/024/027/028/033.

I compared all 25 entries with their frozen matrix clauses, results links, verdicts, raw command/transcript streams, and assessments. All adjacent identity records match candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` and every frozen artifact. No command timed out or left its recorder process group alive.

CLI-117–121 retain the exact candidate documentation/help comparisons for Android CI refusal, emulator selection order, both-platform wording, hierarchy JSON equivalence, and ready-file parent creation. CLI-122 uses its grading `run-2` evidence: a fresh assertion reports 22 documented and 22 live tools, with empty missing/extra sets and the required iOS-only `grantiva_test` and Android-only emulator tools.

CLI-161–164 support the installed runner-home stamp/layout, screen timeout/continuation wording and negative contradiction check, both diff threshold definitions, and agreement among MCP help plus MCP/Android session documentation.

For each paired session-required MCP row, both iOS and Android transcripts return `result.isError: true`, contain no JSON-RPC error, name both `grantiva runner start` and `grantiva run --keep-alive` with the exact project session path, and then successfully answer `tools/list` with 22 tools. The config-present rows use the retained config fixture; the empty-directory rows use the distinct empty fixture. This applies independently to screenshot, tap, swipe, type, accessibility tree/check, and script.

MCP-033's two empty-directory transcripts name the correct platform-specific missing file and remedy: `grantiva.yml` plus `grantiva init` for iOS, and `grantiva-android.yml` plus `grantiva init --platform android` for Android. Both servers continue answering afterward.

Material gaps: **none found**.

The earlier prefix-only review is preserved adjacent as `candidate4-cli-151-175-review.mistaken-prefix-only.md` and is superseded by this corrected ordinal review.
