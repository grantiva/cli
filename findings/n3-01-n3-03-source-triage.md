# N3-01 reassessment and N3-03 source triage

Candidate: `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff676b3c12e951478920fa20e600cdca4e29`. This is a read-only evidence/source assessment.

## N3-01

**Pass is supported.** Attempt 47 supplies the starting-window behavior for tap, tree, and screenshot: all return normal tool results with `isError:true`, exact WDA-starting text, and no start-one advice. Attempt 16c independently supplies the row's post-detach screenshot clause: transcript line 17 records explicit `runner start --detach`, exit 0, and `Runner started (detached)`; transcript lines 61-62 and `mcp/stdout.raw` line 19 record a later screenshot tool response containing `image/png`. The intervening app termination does not invalidate this device-level screenshot clause and demonstrates that it is not coupled to a live app session.

## N3-03

**The missing `port:null` is a product output-contract defect, not a stale matrix expectation.** Three independent exact-candidate contracts agree:

- Matrix N3-03 explicitly requires `"status":"already_running"` with `"port":null` while the existing session is starting.
- `README.md:414-424` says start/stop JSON share `pid` and `port`, then specifically states an `already_running` starting result has `"port": null`.
- `DriverCommand.swift:161-165` intentionally constructs the already-running document with `port:nil` when `existing.isReady` is false.

The implementation loses the promised key in encoding: `RunnerLifecycleDocument.swift:48-52` encodes nil port only when `nullWhenUnrecorded` is true, while the start path leaves that flag false. That flag is currently described and used for stop documents (`RunnerLifecycleDocument.swift:26-28`; `RunnerLifecycleCommandTests.swift:617-621`). There is no focused test for the already-running starting start document. Attempt 47 observes the direct consequence: correct status/PID/platform/app/device keys, but no `port` key.

The minimal correction is to make the already-running starting start document encode nil port explicitly and add a focused lifecycle test asserting `port` exists as JSON null. Text output already meets the contract. This triage does not change the binding failure grade or modify product source.
