# iOS attempts 98e/102b and README examples review

Read-only review on 2026-10-13 against the binding matrix and CLI candidate `8f2cff67`.

## Attempt98e

**B3-L52 [ios]: pass.** Attempt98e uses the exact slow `run --keep-alive` trigger. During its observed starting window, CLI `hierarchy` and `runner dump-hierarchy` exit 1 with the retryable starting-session text and MCP tree returns the matching tool-level error. After bounded readiness in that same run, CLI hierarchy and dump exit 0 with real trees and MCP tree succeeds. The owner, run exit, and stop output tie both phases to the same row-owned session. Exact-head `docs/mcp.md` and `docs/dump-hierarchy.md` agree.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt98e/`.

## Attempt102b

- **B2-K86-a [ios]: substantial partial.** An exact detached `runner start` owns U1; the second `run --no-build` exits 1 in one second, leaves the session usable, identifies a `grantiva runner start` session with its runner PID, and gives the exact `runner stop` project-directory remedy plus unique-simulator alternative. Current attempt64 supplies the separate live keep-alive wording control. A current dead-owner runtime control proving the teardown-force advice was not identified in this scoped review, so the compound row should remain partial unless that retained capture is cited alongside the exact semantic source test.
- **Context rows:** the current-sidecar context correctly renders iOS config, the exact session UDID, Xcode, PID, WDA port and bundle ID. This corroborates MCP-042/X-020 but does not replace IOS-101 or B2-K56 because their binding inputs require a keep-alive session. The synthetic legacy sidecar removes `appId`, but the resulting Runner Session still prints the configured bundle ID rather than `(unknown)`; it therefore does not prove B2-K56's older-sidecar clause.
- **Harness side effect disclosure:** the valid explicit stop completes first and returns the exact PID. The EXIT trap then copies `owner-original.json` back to the stopped PID's sidecar path before its cleanup stop, recreating a stale owner after the product's valid cleanup. `harness-recreated-stale-owner.json` archives the exact bytes. The posthoc cleanup verifies PID 80702 is absent and removes only `/tmp/grantiva-sessions/80702.owner.json`. This harness-created artifact must not be attributed to `runner stop`; it does not invalidate the earlier refusal or context captures.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt102b/`.

## README example rows

- **IOS-124: partial.** Attempt26 proves the install JSON/data-container half, including a concrete `dataContainerPath`, and later current runs prove `--no-build` with explicit bundle/device can pass. No retained current batch was found that executes the README's single joined fixture sequence: parse the just-installed container, seed it, then run the substituted seeded-state flow against that same installed product. Smallest missing input is that exact joined script with the permitted fixture-flow substitution.
- **IOS-147: partial.** Current ensure evidence proves stdout can be captured as the exact UDID, and current explicit-UDID runs pass. No retained current sequence was found that captures `udid=$(grantiva simulator ensure --name "cov-ios-3 iPhone 17")` and immediately uses that variable for the README run. Attempt71b uses different row-clone names and lifecycle goals; attempt99 uses MCP ensure rather than the shell example.
- **IOS-148: partial.** Current session lifecycle evidence proves session-scoped ensure/teardown and deletion, but no allowed current capture runs the literal README sequence with `GRANTIVA_SESSION_ID=cov-ios-tmp` and the exact `cov-ios-3 iPhone 17` name. The historical exact row is quarantined and cannot be imported. Smallest missing input is that two-command owned-device lifecycle with before/after absence proof.

The current README text still documents the fixture-install workflow and durable session pattern, but documentation plus adjacent executions cannot replace these rows' explicit example-runtime inputs.
