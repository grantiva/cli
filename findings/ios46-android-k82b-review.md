# iOS 46 and Android K82-b scoped review

Scope is limited to iOS attempt 46 B3-L18 and Android `B2-K82b-artifact-separation-rerun1`. iOS 47 and Android K17v3 were running when this review began and are excluded. No live command was run.

## Verdict

- **B3-L18 [ios]: approved.** The exact config includes integer `wait: 3`, decimal `wait: 1.5`, an exact visible selector, an ordinary visible selector, and an exact not-visible selector. `diff capture` live stderr and text summary use `Wait 3s` and `Wait 1.5s`; exact selectors alone receive `(exact)`. `run` screens output repeats the same labels. JSON actions are the same strings. Exact candidate `RunnerSessionOutputTests.swift:583-597` pins decimal wait and exact/non-exact formatting. All three commands exit 0.
- **B2-K82-b [android]: approved.** The clean visual capture contains exactly five configured screens under `.grantiva/captures/android`. Subsequent passing and failing runs write named, trace, hierarchy, and failure artifacts only under `.grantiva/run-captures/android`; the configured capture inventory remains exactly five. Approve names exactly those five and compare returns exactly five passing screen results. It writes no artifact-named baseline. Both preseeded legacy artifact-named baselines remain present with their original literal `retained stray baseline` bytes after approve and compare. The exact-head README/Android docs describe the separated paths, and the focused `DiffCommandTests` excerpts semantically require configured-screen filtering for approve and compare.

## Evidence integrity

The Android harness freezes the preexisting campaign `.grantiva`, starts from a clean row-local artifact state, records every command and post-command inventory, copies visible captures/baselines into evidence, and restores the frozen directory through its exit trap. `summary.txt` reports zero aggregate failures. This establishes row-local provenance without treating restored campaign state as generated evidence.

No material unsupported criterion or new breakage was found in this scope.
