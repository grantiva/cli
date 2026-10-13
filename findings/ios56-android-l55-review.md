# Scoped review: iOS attempt 56 and Android B3-L55.2 rerun 2

Candidate provenance: Grantiva CLI `8f2cff67`; runner `fd9d8e8`. No live calls were made.

## iOS attempt 56

**MCP-063 [ios] pass is supported.** `mcp/mcp-capture.json` returns all five configured screens on owned U1, with project-relative `.grantiva/captures/*.png` paths and the documented capture fields. `mcp/post-context.json` retains the same live runner PID, U1 UDID, and WDA port after capture. The subsequent bare capture returns the same screen order, paths, simulator metadata, step actions, and field shapes. Dynamic timestamps and measured durations appropriately differ; “same JSON” is a schema/contract comparison, not byte identity. The retained capture files cover every returned path, and there is no second runner-start command in the harness.

**B2-K86-b [ios] pass is supported under the criterion's first alternative.** Bare `diff capture --no-build` implicitly selects the live session's U1 and captures all five screens with exit 0; `post-capture-hierarchy.json` and `mcp/post-context.json` establish that the same session remains usable, and same-owner stop succeeds. The alternative is disjunctive, so the row does not additionally require the runFlow-screen refusal once session-backed capture succeeds. The cited `DiffCommandTests` source supplies the selection assertion.

## Android B3-L55.2 rerun 2

The literal **fail** is correct and well supported. All three cycles prove a genuinely active owned run using the flow stream, owner sidecar, and live PID; cross-shell stop exits 0, each run exits 130, terminal ready status is `interrupted`, session files are removed, and the wrapper reports zero harness failures. In every active snapshot the ready file is absent, so the required “ready file shows running” observation cannot occur.

This is an expectation conflict rather than a runtime cleanup failure. Candidate `Sources/GrantivaCore/Runner/ReadyFile.swift:163` explicitly normalizes unfinished flows so a ready file never reports `running`, and `Sources/GrantivaCore/Runner/RunnerExecution.swift:182` publishes it from the terminal report. Preserve the matrix fail pending Task 6; do not reinterpret absence during a proved-active run as weak activity evidence.

## Verdict

The two iOS passes and Android literal matrix fail are supported without qualification.

## Addendum: Android foreground lifecycle controls rerun 2

- **B3-L36.1: supported.** Five independent foreground starts ended via cross-shell `runner stop`; all five stop and foreground exits are 0 and carry the required ended-session wording. The first stop begins immediately after the first hierarchy response. The separately provenance-guarded child-runner SIGKILL makes the foreground Grantiva command exit 1 with runner status 9, satisfying the unprompted-death control.
- **B3-L37 [android]: supported.** Plain, quiet and JSON modes all target the recorded foreground Grantiva PID, exit 130, and print the exact emulator-specific SIGINT announcement. Exact source at `Sources/GrantivaCLI/DriverCommand.swift:398` passes `SignalRelay.deviceNoun(for: platform)`; `Tests/GrantivaCoreTests/SignalRelayTests.swift:53-64` pins the emulator wording. No unqualified track caller was found in the production paths reviewed.
- **B3-L56.2: supported.** The fresh SIGINT leg preserves terminal `passed` and exits 0 with byte-identical before/after ready state. The retained stop controls cover earned passing exit 0 and failing exit 1 with failed ready state, summary and error. None becomes 130 after terminal completion.
- **B2-L04 must not receive an Android grade.** Its matrix platform is iOS and its acceptance criteria concern WDA/xcodebuild/simctl-diagnose cleanup on an iOS simulator. Android foreground evidence cannot satisfy or create an Android half for that row.
