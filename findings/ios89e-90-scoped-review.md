# iOS attempts 89e and 90 scoped review

## Attempt 89e

The initial blocked-signal-mask leg is valid and independently useful. `blocked-start.out` records a successful detached iOS start, `blocked-ps.out` records the exact runner process, and `blocked-stop.out` stops that PID while reaping its WDA child. This supports only the N2-18 clause that a parent blocking SIGINT/SIGTERM does not prevent normal detached runner stop.

The later nohup/HUP and killed-runner sequence did not complete: the harness exits 1 after the HUP setup and does not preserve the planned `hup-runner-alive-after`, hierarchy, normal stop, killed-runner, or sidecar-after artifacts. `hup-ready.json` being `interrupted` is not a substitute for those assertions. No HUP-survival, dead-runner cleanup, B2-K79, or D2-30 verdict should be derived from attempt 89e. The valid first leg and incomplete later leg can coexist without treating the harness failure as a product failure.

## Attempt 90 / B2-K03

The B2-K03 grade is supported. The exact four-step fail-early flow produces one failed tap and two later skipped steps. The summary's two skipped lines have no durations or failure glyphs, the `2 steps skipped` total agrees, and `plain-report/report.json`, `flows/flow-000.json`, JUnit, and Allure consistently retain one failed flow with two skipped commands. The JSON run supplies the equivalent structured failure artifact.

The harness's combined-stream glyph-count assertion is invalid because it counts the runner live failure and the Grantiva summary rendering of the same failure. That wrapper issue does not invalidate the summary block required by B2-K03. The current ledger correctly discloses this distinction and joins exact runner source assertions for skipped/pending rendering.
