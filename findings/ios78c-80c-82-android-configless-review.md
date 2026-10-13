# iOS 78c/80b/80c/82 and Android configless MCP review

Candidate provenance: Grantiva CLI `8f2cff67`. Read-only independent review.

## IOS3-OBS / attempt 82: confirmed product failure

Attempt 82 is a minimal, unambiguous reproduction of the force-teardown classifier defect described in the earlier 78b review. A row-owned Python process only slept; its unused positional arguments named the QA Grantiva binary and a newly created, shutdown disposable simulator UDID. It never accessed the device. `teardown.out` nevertheless classifies PID 26041 as `kind: "grantiva"`, `killed: true`, reports `reclaimed: true`, and the sleeper exits `-2` from SIGINT. `ps-before.txt` preserves the exact command and `ps-after.txt` confirms its removal. The teardown exited 0, and exact-UDID guarded cleanup removed the disposable simulator. L76 now captures the defect and source cause.

## Attempt 78c: valid corrected lifecycle proof

The corrected helper exits 0 and watches the actual runner PID 22736 rather than the Python orchestrator PID 22659. `sidecar-observation.json` records both owner and stop markers and an empty final set. The retained JSONL samples preserve the owner contents (`runnerPid: 22736`, `grantivaPid: 22659`, exact UDID), then a stop marker with the matching runner PID/start time and owner PID, then removal of both. Foreground exit is 0 with the normal teardown notice. Force JSON also preserves the separate diagnose reap and device-home cleanup. This is sound evidence for the intended runner sidecar lifecycle; it coexists with the L76 false-positive defect.

## N-05 / attempts 80b and 80c: supported

Attempt 80b supplies five standalone flow failures after launch; all five flow commands exit 1 with the missing first tap rather than a network-400 transport failure. Attempt 80c supplies five CLI/MCP session controls: on every cycle the first request while startup is published returns the explicit `runner session is starting` error, the later ready request returns `Element not found: "No Such"`, and the clients exit 0. The five repeated ready-state missing-label outcomes satisfy N-05's required stability; the starting observations are additive readiness evidence and are not substituted for the row's expected element error.

## MCP-032 and MCP-037 Android: supported

`MCP032-037-configless-build-run-rerun1/` is a copied Android project with no Grantiva config. Its exact requests pass `{module: "app", variant: "freeDebug"}` to the build and run tools. Both client and JSON checks exit 0. Build returns the module/variant and APK path without changing the attached-device inventory; run builds and launches `com.kylebrowning.landmarks` on the owned AVD and returns the same product path. This directly establishes that the arguments stand in for the absent config as MCP-032 and MCP-037 require.

