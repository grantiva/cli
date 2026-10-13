# D2-05 Android compound Maestro-format review

**Verdict: PASS [android].** Evidence:
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/D2-05-compound-maestro-rerun3`.

The frozen `input/grantiva-android.yml` uses `appId`,
`scrollUntilVisible` with `direction: DOWN` and `timeout: 5000`, scalar and
mapping-file `runFlow`, inline `runFlow.commands`, sub-flow screenshots, and
two `extendedWaitUntil` operations with explicit timeouts. The scalar and
mapping sub-flow inputs are also frozen.

`capture.exit` is 0. The runner transcript in `capture.err` reports 21/21
passing steps, including the scroll, all three sub-flow bodies, both
`extendedWaitUntil` operations as `5000ms max`, and five screenshots.
`capture.json` preserves those successful actions and names all five expected
screens: `Scrolled`, `From Scalar`, `From Mapping`, `From Inline`, and `Main`.
Every corresponding PNG is retained under `captures/` with nonzero bytes.
This proves execution rather than parser acceptance alone.

The v1 evidence is excluded because its final state assumption was invalid.
The published v2 harness was never run and did not actually change that stale
tail. Rerun3 corrects the state-sensitive final screen by retaining the
Caching Demo state and waiting for `Cache Policy` without relaunching.

The zsh EXIT trap attempted to assign to the read-only special parameter
`status`, so it did not append the final timestamp or hash manifest. That
post-command archival defect does not affect the frozen inputs, command,
exit-code file, JSON response, full stderr transcript, or copied PNGs. The
runtime evidence itself is complete and internally consistent.
