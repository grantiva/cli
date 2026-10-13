# iOS attempt 111 and B2-K92 retained join

## D2-45 [iOS] — PASS

Attempt 111 runs the exact lifecycle in one live session. `notifications-indexed.json` contains exactly two `notifications/resources/updated` messages for `grantiva://hierarchy`: one after the successful subscribed tap and one after the subscribed script whose first tap ran before its second tap failed. There are no notifications for the pre-subscription failed tap, rejected swipe, subscribed failed tap, or successful tap after unsubscribe. The individual saved responses establish the intended success/error classification, and cleanup stops the exact runner.

## B2-K57 [iOS] — PASS

The same runtime proves the named subscribed branches. Candidate `Tests/GrantivaMCPTests/HierarchyNotificationTests.swift:25-86` supplies the remaining exact semantic controls: a successful mutation without a subscription sends none; rejected and failed calls send none; successful tap sends one; unsubscribe suppresses later updates; and a partially executed failing script sends one. This is the permitted source assertion join, not an inferred result from notification count alone.

## B2-K92 [iOS] — PASS

Current round runtime and exact-head source together cover the compound row:

- Attempt 80c performs five startup cycles. Each initially reports the explicit starting-session result and, once ready, returns `Element not found: "No Such"` with hierarchy guidance; none returns `Network error (400)`.
- Attempt 16c's terminated-app sequence supplies the app-not-running session-tool responses while retaining the matrix-allowed successful screenshot behavior.
- Candidate `Tests/GrantivaCoreTests/WDAClientTests.swift:214+` distinguishes WDA's app-not-running 400 body, ordinary missing-element 404, and unrecognized 400 body preservation. `Tests/GrantivaMCPTests/ToolErrorContractTests.swift:208+` verifies registry `isError` transport for the app-not-running errors. The connection-failure test remains a port-naming transport error.

This row does not require another live retainer session: the five-cycle startup behavior and killed-app behavior are already current runtime captures, while the genuine transport-failure branch is an exact semantic source clause.

## Evidence

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt111/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt80c/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt16c/`
- CLI candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff67`
