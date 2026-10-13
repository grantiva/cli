# L85 source-live verification

Exact source: `6cad3f2b4081f0862cd0e93140eda11c2816b9ba`; release binary SHA-256 `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78`. Runner ba9008/.15 and demo84af unchanged. Source and 28 focused / 2,024 full retry test evidence independently approved. PR215 CI38467031047 passed in8m44s.

This is non-final source acceptance; it does not promote a merged candidate or satisfy Task8/full coverage.

- iOS26 first full attempt failed: WDA timed out fetching hierarchy after Cancel. Both preferred and ordinary label lookups and the click completed; full regression did not reach L85. Raw logs/screenshots preserved in `live-26/`.
- Bounded Cancel replay completed all operations; first/retry source reads returned HTTP200 in0.66s/0.63s. Screenshots before runner stop show Landmarks. The inserted screenshot adds about0.45s before the first read, so this does not prove the original stall transient. Independent review approves only the diagnostic evidence.
- iOS26 full retry used the original unchanged helper and production timing, a fresh project/output and the same exact artifacts. All L65/errors, heartidentifier, Nameplaceholder, quotedDenali, stackretention, twolevelback collision and coordinate controls passed. Independent fresh hierarchy and screenshot show GoldenGateBridge root after semantic Landmarks back.
- iOS27 original full attempt passed the identical acceptance sequence and independent root proof.
- Every helper stopped its own runner and proved session/PID absence. Final exact shutdown/delete removed both owned simulators. Protected owner simulator states and Pixel config are unchanged; scoped resource registries contain neither owned UUID.

Original iOS26 timeout remains a recorded, unreproduced observation with no inferred root cause or silent regrade. Candidate3 must execute the full iOS sequence and transport checks again from the fresh merged candidate; recurrence requires triage, not repeated retries.

Raw paths: `findings/evidence/fix4-85/{build,tests,provision,live-26,cancel-replay,live-26-retry,live-27,final-cleanup}`. Scratch originals remain in this plan SDD with exact manifest/command path bindings.
