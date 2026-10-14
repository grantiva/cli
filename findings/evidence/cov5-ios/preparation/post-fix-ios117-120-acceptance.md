# Bounded candidate5 iOS 117–120 acceptance

Status: **static preparation only**. The candidate5 manifest, binary, session ID, runner home, frozen demo app, device names, and resulting UUIDs are unresolved bindings. No command below has run.

Use the existing `findings/tools/cov5-ios/capture-one.rb` collector after making a reviewed binding-only copy for candidate5. Do not change its capture semantics or create another harness. Preserve candidate4 failures under IOS-117 and IOS-120; candidate5 evidence must use adjacent labels or a candidate5 evidence root and must never overwrite them.

## Required bindings

| token | value supplied by root before activation |
|---|---|
| `<CANDIDATE5_MANIFEST>` / `<CANDIDATE5_MANIFEST_SHA256>` | frozen candidate5 identity |
| `<CANDIDATE5_CLI>` | frozen candidate5 CLI |
| `<CANDIDATE5_SESSION>` | fresh candidate5 iOS session |
| `<CANDIDATE5_RUNNER_HOME>` | fresh candidate5 iOS runner home; bind both runner-home variables |
| `<FROZEN_LANDMARKS_APP>` | authenticated frozen simulator `.app`; no build in this gate |
| `<IOS26_NAME>` / `<IOS27_NAME>` | reserved fresh primary names |
| `<IOS26_UUID>` / `<IOS27_UUID>` | UUIDs returned by the exact create commands |

Always unset `GRANTIVA_API_KEY`. The source/config cwd remains the exact frozen demo `ios` directory containing the unchanged 12 flows and five screens.

## Minimal provisioning

The runtime and device identifiers are the same values used by the approved candidate4 workflow:

```sh
xcrun simctl create <IOS26_NAME> com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-0
xcrun simctl boot <IOS26_UUID>
xcrun simctl bootstatus <IOS26_UUID> -b
xcrun simctl install <IOS26_UUID> <FROZEN_LANDMARKS_APP>

xcrun simctl create <IOS27_NAME> com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl boot <IOS27_UUID>
xcrun simctl bootstatus <IOS27_UUID> -b
xcrun simctl install <IOS27_UUID> <FROZEN_LANDMARKS_APP>
```

Capture absent-name and before/after inventories around creation. Hash the installed app against the frozen source manifest. Then establish named-session ownership by running `simulator ensure --name <IOS26_NAME> --json` and the corresponding iOS 27 command with candidate5 session/home bindings; both must report reuse of the exact manually created UUID, never create another simulator. Stop if a name is ambiguous, an unexpected UUID is returned, or either protected UUID is selected.

## Ordered live gate

1. On `<IOS26_UUID>`, repeat the exact stock invocation first:

   ```sh
   <CANDIDATE5_CLI> run --no-build --simulator <IOS26_UUID> --bundle-id com.kylebrowning.Landmarks
   ```

   Require exit 0, five of five configured screens, 12 of 12 stock flows, and the cached iOS 26 agent line. This is the direct IOS-117 regression.

2. On `<IOS26_UUID>`, repeat the exact diff invocation:

   ```sh
   <CANDIDATE5_CLI> diff capture --no-build --simulator <IOS26_UUID>
   ```

   Require exit 0 and five of five captures. Inspect Lakes and Detail: Detail must show Golden Gate Bridge / Plan Visit rather than Lakes content. This is the direct IOS-120 regression.

3. Only after both iOS 26 checks pass, run the same stock invocation and then the same diff invocation on `<IOS27_UUID>`. Require five of five screens and 12 of 12 flows to preserve the previously passing runtime.

4. If these existing traces already expose the matched accessibility element ID, retain the before/after selector lines and hierarchy excerpt around the second `Landmarks` tap. Do not add a diagnostic run or tracing harness solely to obtain an ID.

The candidate4 trace directly proves that the second `Landmarks` tap reports success while Lakes/Crater Lake content remains and `Golden Gate Bridge` is absent. Matching the selected tab/back-label element is an inference unless the candidate5 trace exposes the matched element identity.

## Scoped cleanup

Authenticate both UUIDs in `<CANDIDATE5_SESSION>`, run per-UDID `simulator teardown --udid <UUID> --force --json`, then `simulator teardown --session-id <CANDIDATE5_SESSION> --force --json`. If either manually created primary remains, delete only its exact authenticated UUID with `xcrun simctl delete <UUID>`. Capture final simulator/session/created-ledger inventories and prove both UUIDs, device homes, leases, and owned workers absent. Do not invoke broad cleanup and do not mutate protected devices.
