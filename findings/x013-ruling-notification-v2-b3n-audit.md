# X-013 ruling, Android notification-v2 review, and remaining B3/N audit

## X-013 is an expectation conflict

The observed cross-platform difference is required elsewhere in the binding matrix:

- B2-K16 requires iOS `bundleId` + `udid` and Android `applicationId` + `serial`, consistently across lifecycle JSON.
- D2-13 repeats those platform-specific start/stop keys and also requires Android's deprecated `udid` alias.
- N2-07 requires Android `applicationId` plus deprecated `bundle_id`, and `serial` plus deprecated `udid`.

The attempt62/Android paired capture implements exactly those contracts. X-013 simultaneously asks for the same JSON keys apart from device naming, which cannot hold when `bundleId` and `applicationId` are explicitly required to differ. This is a Task 6 expectation correction, not a new product defect. A minimal correction is to say that lifecycle/status fields and value types match, while platform identity keys follow B2-K16/D2-13/N2-07. Preserve the current literal X-013 failure until that correction is adopted.

## Android notification-v2 is partial and must not be graded

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K57-D245-notifications-rerun2/`.

Reusable clauses are sound:

- the failed tap before subscription emits no notification;
- subscribe succeeds;
- the successful `Gesture Lab` tap emits exactly one `notifications/resources/updated` before its response;
- the rejected empty tap emits no notification;
- unsubscribe succeeds; the MCP stream remains valid and responsive.

Two required clauses are not exercised:

- The nominal partly-run script fails at step 1 (`Landmarks` is absent on the current Gesture Lab screen), so it proves neither partial UI mutation nor the required notification after a later-step failure.
- The post-unsubscribe `Favorites` tap also fails. Its lack of notification cannot prove suppression after a successful post-unsubscribe UI change.

The wrapper's zero status only shows harness completion. Withhold B2-K57 and D2-45 full-row grades pending the requested corrected v3 inputs.

## Remaining B3/N audit

I normalized the current iOS and Android ledgers against every matrix ID beginning `B3-`, `N2-`, or `N3-`, then rechecked the prior source/gap maps and the latest retained attempt roots. No additional **complete** ungraded row join is supported at this checkpoint.

The nearest reusable groups remain partial:

- iOS B3-L14.1 has the delayed-cancel transport plus CLI immediate/unknown/source legs already integrated in the CLI report; the device ledger still lacks a new independent whole-row basis.
- iOS B3-L52 has exact source assertions for starting lookup, but lacks one retained live window covering all required CLI/MCP starting calls and ready controls.
- iOS B3-L54.1 and Android B3-L54.2 still need their exact teardown/foreground residue sequences; ordinary stop evidence is not a substitute.
- Android B3-L05/L06/L07 still require their named repetition counts, crash timing/selector variants, or high-load pointer-action observations. Stock passes and source tests close only source/control clauses.
- Android B3-L10/L13/L14.2/L18/L19/L20/L23 remain missing one or more exact mode, cancellation, relative-path, cycle, or live-session variants identified in `android-next30-missing-map-3.md`.
- N2-05/N2-07 require the full multi-condition lifecycle/alias document sets. The new X-013 capture supplies started/stopped/no-session shapes but not every already-running, already-exited, multi-session, ensure, and diff document named by those rows.
- N3-01/02/03 are already graded on both platforms; the audit found no missing platform half there. N3-03's existing failure is the L69 null-port defect and should not be duplicated.

Consequently, no worker should add a B3/N grade solely from this audit. The prior maps remain accurate clause-level handoffs, and the smallest missing runtime observations above are still required.

