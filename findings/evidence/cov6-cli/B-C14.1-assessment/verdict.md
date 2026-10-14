# B-C14.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: Re-running the repro: the first command fails in under a second with exit 64 and no video written; the second either succeeds (pass the file type to AVFoundation, or record to a temp `.mov` and move it) or fails before recording with "--output must end in .mov or .mp4". (brief C14)

Fresh candidate5 negative public, docs, MCP, or exact-current-source evidence satisfies this clause without compiler/live action. Evidence: `B-C14.1-run-1/bad-frames.command.json`, `B-C14.1-run-1/extensionless.command.json`.
