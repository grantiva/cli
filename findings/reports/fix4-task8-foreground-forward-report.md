# Task 8 foreground Android forward cleanup report

## Outcome

Implemented the L82 follow-up on `fix4/foreground-forward-cleanup`, based on `fb7af9d1702cd4f294aae48eb5f1ed52dbfe2d88`.

Final source commit: `015521cb75ff46b19aa66790300d6c85d2bd6e3b`.
Draft PR: https://github.com/grantiva/cli/pull/213

A successful foreground Android readiness attachment now remains owned for the full foreground session. The existing once-only foreground cleanup releases that exact attachment after either normal runner exit or SIGINT. Detached startup behavior, rejected/startup-failure attachment cleanup, iOS behavior, output documents, flags, notices, and exit handling are unchanged.

## Cause and fix

`waitForUIAutomator2Port` previously reduced its successful `DriverAttachment` to a `UInt16`. That preserved the published port but discarded the attachment's `detach` callback. The runner used a separate Unix-socket forward and could not release the CLI's dynamically allocated TCP forward.

The function now returns the attachment. Detached start continues to publish its port and intentionally transfers the live resource to detached-session teardown. Foreground start retains the attachment in `ForegroundDriverAttachment`, which is included in the existing `Once` cleanup. Because SignalRelay cleanup is synchronous and exits when callbacks finish, the holder uses the established bounded semaphore pattern to await asynchronous detach for up to 15 seconds.

Cleanup invokes only the retained attachment callback. It does not enumerate forwards or use `--remove-all`, so unrelated ADB forwards remain untouched.

## Semantic RED/GREEN proof

The governing RED is an instrumented-baseline comparison, not an unmodified checkout of `fb7af9d1`. The final source-compatible ownership seam and identical test were present, while the production transfer deliberately retained the candidate behavior: it returned the discovered port without retaining the successful attachment. The test compiled, ran the production ownership seam plus production `holdForeground` lifecycle, and failed four behavioral assertions: release remained 0 instead of 1 on both normal exit and interruption.

Restoring the one production transfer statement, `owner.retain(attachment)`, made the identical test GREEN. `testForegroundHoldRetainsAndReleasesItsDriverAttachmentExactlyOnce` proves:

- the attachment remains retained while the session is live;
- its cleanup runs exactly once after ownership ends;
- a second cleanup attempt is harmless;
- an unrelated attachment is not released.

Existing tests continue to cover rejected failed-launch attachments, startup interruption, iOS startup, exact Android `forward --remove tcp:<allocated>` behavior, and foreground exit/notice contracts.

An earlier preliminary attempt added a test that named the not-yet-existing holder and failed compilation. That was diagnostic only, was not a semantic RED, has no governing raw artifact, and is excluded from the acceptance proof.

Governing evidence:

- Instrumented RED source diff SHA-256: `8b3e63d4ed512d4b92a33409f3ebf943c11fd7b199fb51f4e22c5cd2aec01adf`; transcript SHA-256: `f050fc88ab4e10c6cd1bbd8165bc6d9fed2e72e820e46264466863e607edb00b`.
- GREEN/final source diff SHA-256: `327d33550fe59ca2ed7f468bceec2051df0281d4b709dbd6666d22406cfae79b`; transcript SHA-256: `dfc453a5b0857a23c29635cd3be53f51a269b5e68a0da81326b4627ce04cb19d`.
- Governing full-suite transcript SHA-256: `c28884c098c35f1c0100dffef5169b91fd2f730653079299b8f4b62e3ca269c1`.

## Validation

- Focused lifecycle suite: 70 tests, 0 failures.
- Final full Swift suite: 2,016 tests, 0 failures (MCP 281, Core 971, CLI 663, API 101).
- `git diff --check`: clean.
- Focused, semantic, and full runs used separate fresh empty runner homes, `GRANTIVA_SESSION_ID=fix4-4-forward`, and unset API environment variables. The governing full home `/private/tmp/grantiva-fix4-4-forward-final2-home` remained absent/empty.
- No device commands were run. Controller owns the required ready/SIGINT, normal foreground stop, absent-app, unrelated-forward, and post-fix live verification.

Raw evidence is under `findings/evidence/fix4-4-forward/`. `semantic-red/` and `semantic-green/` contain the exact source diffs and transcripts; `final-source.diff` is the final source; `full-swift/final2-transcript.txt` is the governing full run. Earlier full attempts remain separately preserved as `transcript.txt` and `final-transcript.txt`. PTY transcripts preserve the test process's emitted terminal streams together.

## Scope review

The product diff changes three files: foreground readiness keeps the attachment, a small once-owned synchronous release bridge is added, and one lifecycle regression test covers normal/interrupted exact ownership. No runner source, public API, global cleanup, device behavior, or release artifact changed.

## Independent review P1 resolution

Independent review of source commit `5d8cd234ab88c240a43a4c527a635306dd668f42` found a startup ownership race: synchronous signal cleanup could observe an empty holder and return while Android discovery was still acquiring an attachment. The later handoff could then retain an attachment after the once-only cleanup had already run.

Commit `015521cb75ff46b19aa66790300d6c85d2bd6e3b` serializes discovery and cleanup at that handoff. Cleanup marks release requested and waits across an in-progress acquisition. A successful discovery either transfers ownership before cleanup, in which case cleanup waits for its detach callback, or sees cleanup already requested, rejects the transfer, completes the attachment's detach, and only then wakes cleanup. Startup paths that cannot produce an Android attachment explicitly finish acquisition so cleanup does not wait unnecessarily. The existing 15-second bounded cleanup policy remains in place.

Two deterministic production-seam tests cover both orderings with a deliberately delayed detach callback:

- cleanup-before-transfer rejects the late attachment and neither the transfer nor synchronous cleanup returns until detach completes;
- transfer-before-cleanup keeps the attachment owned and synchronous cleanup does not return until detach completes.

Review-fix validation used `GRANTIVA_SESSION_ID=fix4-4-forward`, unset API environment variables, and distinct fresh homes that remained absent/empty:

- `RunnerLifecycleCommandTests`: 72 tests, 0 failures; transcript SHA-256 `bd4aabbbccfdb9b135ddcee0dc9d3044818f25d57856abc0826b36e9c79dd583`.
- Full `swift test`: 2,018 tests, 0 failures (MCP 281, Core 971, CLI 665, API 101); transcript SHA-256 `1d482f7465dfa4c38661aef72e2bd8921bf891a139b7a8e53b7347cf24b1fec2`.
- Review-base scoped diff SHA-256 `ab793744cf03df4d1c688f767155f986a4bc58d4ace8789ad9aaec683d88cc32`; complete base diff SHA-256 `b013224ff6b60496a87b746c1e63ff5e2848629418f44d7292e5ec691a9d2b3f`.
- `git diff --check` passed.

The review-fix transcripts, command/result metadata, checksums, and exact source diffs are under `findings/evidence/fix4-4-forward/review-fix/`. The earlier semantic RED/GREEN metadata cannot be reconstructed beyond its preserved source diffs, transcripts, and hashes; the preliminary compile failure remains explicitly non-governing. The corrected governing full-suite metadata now points to `final-source.diff`.

The initial PR CI run `38440764200` failed only in `SimulatorManagerTests.testBootWaitingOnATwinsBootIssuesNoSecondBoot` at line 503 (`nil` versus `Optional(true)` after 1.505 seconds). Its log is preserved at `/private/tmp/grantiva-pr213-ci-failure.log`; this unrelated timing failure did not justify widening the patch, and the new head triggers a fresh CI run.

L83, the runner's unconditional removal of an unowned `tcp:6790` forward, remains outside this CLI change. No device commands were run for the review fix.
