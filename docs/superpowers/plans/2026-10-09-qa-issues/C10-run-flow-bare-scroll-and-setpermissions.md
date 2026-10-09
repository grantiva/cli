# Support bare `scroll` and header-appId `setPermissions` in `run --flow`

Severity: wrong-result
Platforms: cli, ios
Found by: CLI-F30 (matrix rows CLI-063, CLI-065)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
Bare `- scroll` scrolls down (Maestro semantics, and README §Maestro Compatibility lists `scroll`); `setPermissions` uses
the flow header's `appId:` (or is skipped with a warning). Source: README §Maestro Compatibility.

## Actual
```
    ✗ scroll (0ms)
      ╰─ Invalid scroll direction (cause: invalid direction: )
```
```
    ✗ setPermissions (0ms)
      ╰─ No app ID for permissions (cause: no appId specified)
```
although the flow header has `appId: com.kylebrowning.Landmarks`. The same `scroll` file passes in parsed mode (it becomes
`swipe: UP`). Triage also saw `--flow` with no config demand `--bundle-id` despite the flow's `appId:` header.

## Repro
1. Boot a simulator. Use fixtures/maestro/scroll.yaml and setPermissions.yaml (branch qa/cli), replacing `appId:` with
   `com.apple.Preferences` if landmarks-demo is not installed:
   ```
   grantiva run --flow fixtures/maestro/scroll.yaml --platform ios --simulator <udid> --no-build --bundle-id com.apple.Preferences
   grantiva run --flow fixtures/maestro/setPermissions.yaml --platform ios --simulator <udid> --no-build --bundle-id com.apple.Preferences
   ```

## Evidence
- findings/evidence/cli/maestro/scroll.flow.log, setPermissions.flow.log (and scroll.parsed.log, which passes)

## Suspected cause
The errors come from the embedded grantiva-runner 1.1.18-grantiva.7 command handlers (outside Sources/): `scroll` with no
direction is not defaulted, and `setPermissions` reads only its own `appId`, not the flow header's. Grantiva could also
normalise the flow before handing it to the runner (RunnerSession.runFlowFiles, Sources/GrantivaCore/Runner/RunnerSession.swift:238),
e.g. via FlowReferenceResolver, and take the bundle ID from the header when `--bundle-id` is absent.

## Acceptance criteria
- Re-running the repro, both steps pass (`scroll` scrolls down; permissions are set for the header's app).
- `run --flow` with no config and no `--bundle-id` uses the flow's `appId:` header.
- A runner-side test (or a GrantivaCoreTests case on the flow normaliser) asserts bare `scroll` gets direction DOWN and
  `setPermissions` gets the header appId.
