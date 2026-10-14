# Candidate 4 CLI ordinal 101–150 review

Verdict: **APPROVED** — the results-file ordinal slice supports 48 passes and two `n/a` outcomes (CLI-152 and CLI-160).

This slice is CLI-086, 087, 088, 139–142, 091, 108, 101–107, 143–151, 097–100, 152–160, and 109–122 in the exact order recorded in `cov5-cli-results.md`. I compared all 50 entries with their frozen matrix clauses, read every verdict and the relevant raw streams, and checked every available identity record. All executed captures bind candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; no identity mismatch, timeout, or capture cleanup failure occurs.

The parser and lifecycle-negative rows have the required exits, streams, and exact diagnostics. The MCP rows retain their protocol transcripts rather than relying on empty process stdout, and prove initialization, the 22-tool list, session guidance, and platform disambiguation. Documentation/example rows retain the compared excerpts or live help/protocol output needed for their literal agreement clauses.

CLI-152 is correctly `n/a`: its matrix clause explicitly says the install examples are not run because Global Constraints prohibit installing or building another Grantiva. The evidence retains the candidate README excerpt and hash. No pass is claimed for either install command.

CLI-160 is correctly `n/a` for the provisioning-script leg because this host is already provisioned, exactly as the matrix permits. Its separate export leg is supported by a candidate-bound capture showing the three documented exports expanding in the shell preamble. The one command record therefore supports the applicable export clause and does not convert the provisioning script into a pass.

CLI-153's first two rejected scheme fixtures remain preserved. The grading capture uses the scratch Xcode copy under the device-free guard, runs doctor/init/runner install, records init's multiple-scheme warning, resolves that fixture-only prompt, and reaches the required unauthenticated `ci run` boundary without booting a device. CLI-155's truncated first fixture, CLI-156's missing-file first fixture, CLI-099's wrapper-flag harness failure, CLI-100's ambiguous first leg, and CLI-142's same-version fixture are likewise retained and excluded rather than overwritten.

Material gaps: **none found**.
