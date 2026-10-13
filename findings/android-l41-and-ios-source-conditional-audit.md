# Android B3-L41 and iOS source-conditional audit

## B3-L41 [android]: PASS

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L41-variant-module-rerun2/`.

The exact current runtime satisfies every observable clause:

- Invalid variant text exits 1 and adds `Variants of :app: freeDebug, freeRelease, paidDebug, paidRelease.`
- Invalid variant JSON exits 1 and its `errors` array contains that identical line.
- Invalid module exits 1 and adds `Modules: app.`
- The independent bounded `./gradlew :app:tasks --all --console=plain` call exits 0 and lists `assembleFreeDebug`, `assembleFreeRelease`, `assemblePaidDebug`, and `assemblePaidRelease`. Those four buildable application variants exactly equal the diagnostic list; AndroidTest/UnitTest and aggregate tasks are correctly excluded.
- Every retained command records the exact cwd/argv and a preflight load below 20.

Candidate `8f2cff67` supplies the required implementation, tests, and docs: `Sources/GrantivaCore/Android/GradleBuildRunner.swift:97-179` parses one bounded task listing and adds the diagnostic; `Tests/GrantivaCoreTests/GradleBuildRunnerTests.swift:121-200` asserts both variant and module cases and the bounded fallback; `docs/android.md:45-46` documents the exact lines.

## B-I15.2 [ios]: still missing exact runtime input

No allowed current-round evidence found in the indexed attempts kills WDA/GrantivaAgent while leaving the runner/keep-alive process live and then captures hierarchy. A dead runner sidecar (for example attempt104b) correctly becomes no-session, but it does not exercise URL timeout/refusal mapping against a live runner port. Candidate source/tests may assert `.timedOut` and `.cannotConnectToHost` mapping, yet the matrix input explicitly requires hierarchy after the agent died. Keep ungraded pending that bounded live-runner/dead-agent observation.

## IOS-088: still missing exact current runtime input

Attempt104b proves stale dead-owner cleanup semantics, but it does not place a stale `.grantiva/session.json` and then start a replacement detached runner. Historical IOS-088 captures are quarantined. The smallest missing current artifact is the stale session file, successful start JSON with a new live pid, rewritten session document, and cleanup stop.

## B2-K107-a [ios]: 106c narrows but does not close the lock observation

Attempt106c proves targeted teardown removes the exact manual device home while leaving the externally booted simulator alive. This supports the deleted-home lifecycle behavior. It does not inventory `<runner-home>/locks/<udid>.lock` before and after that teardown, so it cannot by itself supply K107-a's explicit lock-file observable. Joined source tests still establish release/unlink-race/deleted-home semantics, and attempt103b proves lock removal on stop. The remaining iOS gap is one retained lock inventory around teardown/delete, not another full lifecycle run if such an inventory already exists.
