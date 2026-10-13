# iOS attempt 44 scoped review

Scope: attempt 44 grades for X-005, IOS-145, IOS-128, and IOS-157, plus the Android B2-K05 citation correction. No live command was run. The concurrently running Android K17/K81 batch is excluded.

## Finding

**Important — X-005 is not yet a complete cross-platform comparison.** `cov3-ios-attempt44/build-json.out` is a valid current-candidate successful default `build build --json` document with top-level `destination`, `duration`, `errors`, `productPath`, `scheme`, `success`, and `warnings`. I found no retained current Android successful default `build build --json` output. `build-install-contracts-exact-rerun1` has successful text-mode builds and a JSON invocation only for failing `--variant noSuchVariant`; that cannot establish the successful Android top-level shape required for the comparison. Grade the iOS half/evidence contribution, but do not close X-005 until it is joined to exact current Android raw.

## Approved rows

- **IOS-145:** approved. The four bare README commands run from the retained project/config: capture succeeds with five screens; the initial compare exits 1 and reports exactly five new screens with approval guidance; approve succeeds; the second compare exits 0 with five passing screens. The harness preflight verifies the config's `simulator: cov3-ios-26` maps to owned U1, satisfying the controller safety ruling without altering the documented command forms.
- **IOS-128:** approved. Both `run` and `diff capture` accept the same explicitly spaced `--derived-data-path`; retained `derived-products.txt` shows the built `Landmarks.app` beneath that exact directory, and both commands exit 0.
- **IOS-157:** approved. `diff compare --capture` uses the exact scheme, U1 simulator, bundle ID, and spaced derived-data path. It performs capture and returns a passing five-screen comparison; the retained product path is under the specified derived-data directory.

## Android citation follow-up

The B2-K05 ledger now cites `findings/evidence/cov3-android/source-runtime-joins/B2-K05/` and explicitly labels the fd9d8e8 duration-consistency assertion as inspected rather than newly executed. This addresses the prior minor citation finding; the runtime/source join remains approved.
