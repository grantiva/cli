# X-013/X-017/X-024 paired review and L70 review

Evidence reviewed:

- iOS: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt62/`
- Android X-013/X-017: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/X013-X015-X017-android-rerun1/`
- Android X-024: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K33-X024-verbose-processes-rerun2/`
- Matrix: `2026-10-13-round3-coverage-matrix.md:1207,1211,1218`

The two Android doctor calls made from the iOS-only attempt62 workspace exited 1 and are excluded. They are redundant harness probes, not the Android side of X-017. The native Android capture is the eligible counterpart. All eligible iOS controls exit 0.

## X-013: literal matrix failure

The text output has the same message structure, with the expected platform labels (`WDA port` versus `UIAutomator2 port`), and both stop messages use `Runner stopped (pid N)`. The shared JSON keys and values also agree in type and meaning: `bundle_id`, `log`, `pid`, `platform`, `port`, `status`, and `udid`; stop additionally shares `killed`, `reaped`, and `runnerPid`; no-session stop is exactly `{"status":"not_running"}` on both.

The complete JSON key sets are nevertheless not the same apart from device naming. iOS adds `bundleId`, Android adds `applicationId`, and Android adds `serial`. `serial` can reasonably be treated as device naming; `bundleId` versus `applicationId` is application identifier naming and is outside that exception. Preserve X-013 as a literal matrix failure rather than grading it pass from the shared subset.

## X-017: pass

The eligible `doctor --platform ios` and `doctor --platform android` text and JSON captures are complete. Every JSON record on both platforms has `message`, `name`, `section`, and `status`, with optional `fix`; both use exactly the status vocabulary `ok` and `warning`. Text uses the same section/status presentation and summary vocabulary while the check names correctly differ by platform. This satisfies the requested record keys and status-word comparison.

## X-024: pass

Both commands use the exact `08-caching.yaml` input and exit 0. iOS `logs-flow08.err` and Android `run-plain/stderr.log` put application lines on stderr, prefix every such line with `[log]`, and interleave them with runner/session narration rather than collecting them in a separate trailing block. Platform-native payload formats differ, but the prefix and interleaving form match. The previously reported exact-input gap is closed by attempt62.

## L70: approved

`L70-baseline-filename-migration-documentation.md` accurately limits the defect to public documentation. It cites the fresh attempt57 literal filename, legacy `%20` compatibility, and approve-time migration evidence; exact-head `BaselineStore.swift` and `ScreenArtifactTests.swift`; and the two independent reviews that found no corresponding public note. Its acceptance criteria describe the observed behavior without asking users to rename working legacy files or requesting a runtime change. This matches the binding matrix substitution of README/public docs/release notes for the removed changelog. No material correction is needed.

