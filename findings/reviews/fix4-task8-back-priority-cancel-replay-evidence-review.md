# Task 8 iOS 26 Cancel replay evidence review

## Verdict

**Evidence verdict: APPROVED as a bounded diagnostic.** The replay completed with the approved source and binary identity, all direct WDA operations returned HTTP 200, both post-click source requests completed promptly, the retained screenshots show the edit sheet dismissed with Landmarks foreground, and scoped cleanup removed the exact runner process and project session.

**Classification verdict: the original timeout remains an unreproduced, unresolved iOS 26 WDA hierarchy-snapshot failure.** This replay rules out a deterministic failure of the Cancel lookup/click path under the captured conditions. One successful replay does not prove that the original failure was transient, does not replace its immutable evidence, and does not establish full iOS 26 acceptance.

**Next-step verdict: a controlled full iOS 26 retry is warranted.** The original full run stopped at Cancel and never exercised L85. A fresh-project, fresh-output rerun with the same frozen provenance is the smallest run that can both test recurrence in the real helper timing and reach the previously unexecuted L85 criterion. Its result must be additive; it must not overwrite or regrade the original failure.

## Evidence checked

- `run.json` binds the replay to source HEAD `6cad3f2b4081f0862cd0e93140eda11c2816b9ba`, binary SHA-256 `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78`, and owned iOS 26 simulator `DE2663B5-C24E-42DA-998D-20F7A80054B3`.
- Status, preferred Cancel lookup, broad Cancel lookup, the selected first-element click, and both source requests returned HTTP 200. The preferred lookup remained empty; the broad lookup selected element `4B010000-0000-0000-A7DD-000000000000`, preserving the production fallback path under diagnosis.
- The first source request completed in about 0.66 seconds and the immediate retry in about 0.63 seconds, each returning 51,359 bytes. Neither timed out.
- `immediately-after-click.png`, captured before the first source request and before runner stop, shows the Landmarks root with the edit sheet and keyboard gone. `after-source.png` still shows Landmarks. This directly supplies the foreground evidence that the original post-stop Settings screenshot could not supply.
- `replay-result.json` retains `acceptanceRegraded: false` and `originalFailurePreserved: true`. Cleanup records runner PID 56512 absent, the project session absent, no cleanup errors, and no simulator creation or deletion attempt.

## Interpretation limits

The replay isolates the production route shapes but does not reproduce the exact timing of `UITools.tap`. After the click returned, the helper spent about 0.45 seconds capturing the first screenshot and then retained its delay before requesting source. The first source began about 0.95 seconds after the click completed, versus the production helper's roughly 0.5-second post-tap delay. That additional screenshot latency may have allowed the dismissal/accessibility transition to settle. Consequently, the replay proves recovery and successful hierarchy production in this run; it does not disprove a timing-sensitive stall at the production sampling point.

The result also cannot distinguish a rare WDA defect from a state-dependent simulator/accessibility condition. It supplies no recurrence rate. Calling the original event proven transient, fixed, or non-product would exceed the evidence.

## Full-retry ruling

Run the already approved full iOS 26 helper once with a fresh project and fresh output, while preserving the original failed run, its live evidence, the raw WDA runner log, and this replay unchanged. Require the same frozen source/binary/device ownership checks and retain ordinary-label Cancel evidence, the full L85 collision sequence, screenshots, raw messages, and exact cleanup. A pass may qualify the retry on its own terms and show the source change can complete the intended campaign; it should coexist with an explicit record of the earlier timeout and this timing-limited diagnostic. A repeated timeout remains a live reliability failure and should stop acceptance rather than trigger repeated retries.

## Scope

This was a read-only review of the retained replay artifacts. I did not run tests, issue device commands, modify source, or execute either helper.
