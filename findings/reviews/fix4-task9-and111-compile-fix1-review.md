# Task 9 AND-111 compile collector fix1 re-review

**Specification compliance: APPROVED for the bounded future collector operation. Code quality: APPROVED within the reviewed scope.** All four original findings are addressed. No new breakage was found in the scoped changes.

This is static code approval, not an AND-111 row verdict or a clean-candidate/source-window finding. The existing Swift full-suite NONPASS remains unchanged. The root controller retains scheduling and execution responsibility.

Verified hashes:

- Fixed helper: `d1cdc4073e5a26a57d63d246b8840fc655b6d670b4f0ea61fcd920138ac588c9`
- Helper fix diff: `bcab4e33a7d55f45053b4a2fa7277c93736a9ee76e5e5283a95a68f8c77f84a4`
- Fixture fix diff: `87a30a89f1130e6da224bbaef943f3a2cc63643d80081b8cb302638b890da40c`

## Original finding dispositions

1. **Gradle project cache — resolved.** Generated `.gradle/` files are now allowed alongside the two scratch build roots. Unexpected siblings remain rejected and tracked input hashes remain fixed. The literal public command and reviewed config are unchanged. The fake fixture exercises an ordinary project-cache file as well as an unexpected sibling.
2. **Frozen runner identity — resolved.** The runner-home proof now records non-following entry kinds, modes, regular-file hashes/sizes and symlink target text. This preserves the valid existing cache symlink while detecting retargeting or removal. The candidate's installed runner path/hash is explicitly validated in both frozen-state snapshots. Separate fake checks cover symlink retarget and a preexisting binary mismatch.
3. **Precompile confinement and freshness — resolved.** The absolute output path is checked against scratch, frozen repositories, home and artifact paths before creation. The before scratch snapshot must contain no generated files, links or special entries before command-start or compilation. Unexpected scratch symlinks are now represented and rejected instead of silently omitted. The reviewed existing input copy remains compatible with these checks.
4. **Compile-failure postflight — resolved.** The sole compile invocation uses recorded-result mode for nonzero/timeout results. `post_compile` attempts after-state and source capture, collects subsequent failures, writes exclusive `terminal-nonpass.json` with the original compile failure first, and returns without acceptance. Passing compile plus failed postflight also cannot produce passing acceptance. The fake nonzero and timeout paths check both after-snapshot attempts and terminal non-pass records. No repair, cleanup or retry path was added.

## Preserved boundaries and operational interpretation

Candidate/provision/shutdown/input/review hash pins, exact compile-only argv, absence of a device argument, frozen homes, API-key removal, JDK21/SDK settings, protected/owned device comparisons and external-join fields are unchanged. The new validations consume existing candidate fields and remain compatible with the actual pinned shutdown artifact. Ordinary preflight validation failure still refuses compilation.

On a recorded non-pass path the helper returns without writing `acceptance.json`; the controller must consume the terminal record and acceptance presence/content, rather than equating the helper process returning normally with an AND-111 pass. This matches the explicit evidence contract and does not replace the failure.

The fix report, changed code and fixture diff were inspected. Reported seven fake-check passes and syntax verification were not rerun. No build, test, device query/action, network call, source/helper edit or live collector execution occurred. Only this review document was added.
