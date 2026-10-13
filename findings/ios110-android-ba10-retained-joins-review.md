# iOS attempt 110, Android B-A10.1, and retained joins

## Completed runtime reviews

- **IOS-088 — PASS.** Attempt 110 writes only a stale `session.json` with dead pid 999999; `kill -0` confirms the pid is absent. A new detached start exits 0, replaces it with pid 1288, reaches a real Landmarks hierarchy after the expected starting responses, and publishes a ready session with the correct bundle, UDID, and port. Exact stop exits 0, reports pid 1288, and removes the session. No fabricated process was touched.
- **B-A10.1 [Android] — PASS.** `B-A10.1-early-refusal-no-capture-rerun1/assertions.json` has all eight checks true. The competing run refuses with the exact emulator ownership message and teardown/ensure remedies, has no generic child-exit suffix, leaves the owner alive, and leaves the capture inventory byte-identical. Exact cleanup stop succeeds.

## Analysis-only joins

| Row | Verdict | Evidence mapping |
|---|---|---|
| B-I05.2 [iOS] | Still partial | Exact runner `fd9d8e8` source uses native WDA predicate/class-chain lookup and quote escaping, but attempt 46 is a wait/exact-selector screens run; it does not execute `grantiva_script {tap: 'Mount "Denali"'}`. The named script runtime remains the smallest missing clause. Source semantics alone cannot prove the required quoted-label live fallback. |
| D2-39 [iOS] | PASS | Attempt 105b current context names `source: grantiva.yml` and, for the live keep-alive session, pid, `wda_port`, bundle ID, and UDID. Its legacy context names `source: .maestro/ (no grantiva.yml)` and uses `(unknown)` only for the deliberately omitted older bundle ID. Retained configless/platform context captures cover the Android-only directory under `--platform ios`. This joins consistently with the already approved Android K56/context evidence. |
| B2-K23-b [iOS] | PASS | Attempt 66 exactly exercises config without `bundle_id` and flow header `appId: ${APP_ID}`. Under `--no-build`, it exits 1 with the documented rule that project detection runs only when building and tells the user to pass `--bundle-id` or configure appId/bundle_id. With build enabled, project detection resolves `com.kylebrowning.Landmarks`, installs it, and the flow passes. This is the matrix's explicitly accepted documentation option and matches the exact ProjectResolution semantics. |
| IOS-126 | Partial from these attempts | Attempt 66 closes the `${APP_ID}` ignored plus detection/no-build tail of the precedence chain. It does not by itself re-prove the row's flag-over-config, config-over-app-file, and app-file-over-flow inputs. Those need exact current retained captures from the earlier priority runs before the full row is graded; attempt 68 is output-mode evidence and adds no precedence branch. |

## Provenance

- iOS: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt110/`, `cov3-ios-attempt105b/`, `cov3-ios-attempt66/`, `cov3-ios-attempt46/`
- Android: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B-A10.1-early-refusal-no-capture-rerun1/`
- CLI candidate `8f2cff67`; runner candidate `fd9d8e8`
