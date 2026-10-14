# Candidate 4 CLI synthetic-gap closeout review

Verdict: **APPROVED** for the newly completed N2-04, D2-23, and D2-42 evidence. All three promotions from pending to pass are supported.

This review is limited to the new synthetic captures and their literal matrix clauses. It does not reopen the prior direct-row reviews.

N2-04's fresh configured A/B fixture proves the full filter sequence. JSON approve and compare include only A and B and list `failure-123` under `ignored`; after removing the stray, approve omits `ignored`; with only the stray, the command exits nonzero and names configured screens A and B as missing. The retained command records and streams support the required exit and output distinctions.

D2-23 joins its fresh captures narrowly. The no-baseline and partial-baseline legs both return `passed: false`, with configured screens represented as `new_screen` where their baselines are absent. The separate red/blue perturbation produces a `failed` result with the actual pixel and perceptual values and both thresholds in the public message. The current-tree CI test join supplies the explicitly nonfailing `ci run` new-screen sibling without claiming a device/compiler execution.

D2-42's fresh MCP calls return normal non-`isError` payloads. Compare reports `passed: false`, A and B as `new_screen`, and the stray under `ignored`; approve approves only A and B and reports the stray under `ignored`. Its only-stray diagnostic is explicitly joined to the fresh candidate-bound N2-04 control rather than inferred from source.

All inspected command identities bind candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783` and the matching QA executable. No inspected capture timed out, retained a live process group, or reported failed cleanup.

Material gaps: **none found** for these three rows. The resulting direct-row ledger total of 415 pass, five pending, and five n/a is consistent with the reviewed evidence; the remaining pending rows are outside this closeout.
