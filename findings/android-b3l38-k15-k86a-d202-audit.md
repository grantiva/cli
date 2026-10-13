# Android retained-evidence audit: B3-L38-a, B2-K15, B2-K86-a, D2-02

Candidate source is Grantiva CLI `8f2cff67`. Historical round-2 verdicts are not used as runtime evidence.

## B3-L38-a [android]: partial; foreground starting/ready is supported

`starting-session-contracts-rerun4` is valid current foreground evidence. `run/starting-observations.json` polls from absent to a portless Android `state: starting`; while starting, the hierarchy resource returns `-32002`, `grantiva_a11y_tree` returns `isError: true`, all other retained session-tool responses use the same UIAutomator2-starting/retry text, and `dump-starting.err` prints that text. `ready-observation.json` then records `state: ready`; ready MCP hierarchy/tree attach successfully. The public starting-session wording is present in candidate `docs/mcp.md`.

The full row is not closed by this directory. It runs foreground start only, and does not include the separately required detached 100 ms timeline or a synthetic dead-pid owner followed by CLI/MCP no-session checks. Smallest gap: join a current detached-start timeline and current dead-sidecar capture if they exist elsewhere; otherwise those two bounded inputs remain.

## B2-K15 [android]: not supported by the retained candidates reviewed

The current `B3-L46-installed-retention-rerun2` teardown JSON is not a substitute: all three documents explicitly say `runnerSessionStopped: false` because no detached runner session was active. Other retained secondary-device teardown batches establish emulator lifecycle behavior but do not demonstrate teardown of the serial named by a live detached session.

The smallest missing runtime is the exact row input on a row-owned secondary emulator: detached runner on that serial, targeted text and JSON teardown proving the selected stop/refusal policy, session/lease cleanup, and an unrelated serial left intact. Source assertions should then be joined from `EmulatorCommandTests`. `teardown --all` remains a separate named clause and needs an observable source/runtime join; ordinary teardown without a session does not cover it.

## B2-K86-a [android]: source semantics supported; exact runtime refusal missing

Candidate `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorLeaseTests.swift:232-260` explicitly distinguishes handed-off `runner start` ownership from `run --keep-alive`, including the Android `Emulator emulator-5554 is held by a grantiva runner start session` prefix and runner-stop advice. This satisfies the named semantic-source clause.

`starting-session-contracts-rerun4` does not exercise the row's refusal: its second `runner start` returns the idempotent `already_running` result. No current retained `run --no-build --flow ...` refusal against that live handed-off owner was found in the reviewed index, and the keep-alive/dead-owner controls are not co-located as an exact K86-a runtime set. Keep partial. Smallest gap: one run refusal while a row-owned detached start remains intact, joined with an existing keep-alive wording capture and a dead-owner teardown-force capture.

## D2-02 [android]: failure ordering supported; pass half missing

`output-contracts-exact-rerun2/B2-K20-ready/ready.json` is a current stock-style screens-plus-flow ready document. It lists `screens` first and `01-browse` second, has overall `failed`, and retains the existing `reportDir`. The timeout and interrupted ready documents in `B2-K10-K80-screens-timeout-interrupt-rerun1` corroborate that report path/state handling.

The literal criterion also says `reportDir` is retained when the report was requested on pass or fail. The retained Android index reviewed here has the exact screens-first ready document only for failed/interrupted outcomes; it lacks a matching passed stock ready file with an explicit report directory. Therefore the row remains partial. Smallest gap: a passed current stock screens-plus-flows ready file from an already retained run, if available; no source-only inference should replace that explicit pass artifact.
