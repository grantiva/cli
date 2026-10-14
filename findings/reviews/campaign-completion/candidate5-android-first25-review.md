# Candidate 5 Android first-25 checkpoint review

## Decision

**CHANGES REQUIRED.** The checkpoint supports 19 proposed PASS rows and all three proposed BLOCKED rows. Three proposed PASS rows need narrow evidence supplements before acceptance: AND-001, AND-007, and AND-010. This review is read-only and is limited to the canonical first 25 Android keys.

The reviewed checkpoint is `cov6-android/findings/evidence/cov6-android/first25-verdicts.md` with its `first25-artifact-manifest.json`. The canonical order is AND-106, AND-107, AND-108, AND-001 through AND-018, AND-109, AND-146, AND-110, AND-019.

## Required corrections

1. **AND-001 — resulting AVD device definition is not retained.** The retained evidence proves that `cov6-android` was absent, the public command created and booted it, stdout contained only `emulator-5554`, the resulting emulator identified as `cov6-android`, and its owned process was captured. The literal clause also requires creation with `avdmanager create avd -d pixel_8`. No retained command/output or resulting AVD configuration proves `pixel_8`; the pre-existing `Pixel_8_API_35` inventory is a different AVD and cannot prove the new AVD's device definition. Add a read-only retained observation of the created AVD configuration/device definition or mark this clause pending.

2. **AND-007 — default system image is not proven.** `AND-007/join-and004.stderr` only says that `cov6-android-2` was created and shutdown. AND-004's public argv correctly omits `--system-image`, but neither row retains the invoked `avdmanager` argv, resulting AVD config, nor another observation binding the created AVD to `system-images;android-35;google_apis;arm64-v8a`. Add a read-only retained observation of the resulting AVD target/tag/ABI or mark AND-007 pending. Reusing AND-004 is legitimate only after that literal value is evidenced.

3. **AND-010 — forward removal lacks an after-observation.** The evidence proves a runner was started, forwards existed before teardown, the public command exited 0 and reported stopping the runner/killing the emulator, the runner process was absent afterward, the session disappeared, and the emulator was absent from adb. The literal clause separately requires that the serial's forwards are removed. There is no `adb forward --list` after-capture. Add that narrow retained after-observation or keep the forward-removal clause pending.

These are evidence gaps, not candidate product failures, and no replay of the completed operations is implied.

## Supported rows

The retained raw evidence supports the proposed outcomes for AND-106, AND-107, AND-108, AND-003 through AND-006, AND-008, AND-009, AND-011, AND-013 through AND-019, AND-109, and AND-146, subject to the exclusions above.

- AND-106's report is `passed`, 12/12, with each stock flow named and passed. Its per-flow records retain the favorite removal sequence and final empty-state assertion, plus the edit flow and its `Edited` capture.
- AND-107's join hashes resolve exactly to the current candidate 5 Android smoke review, crash command, result, and report. That accepted evidence records `app_crash`, the dead-app behavior, and timing.
- AND-108's five captures are retained. I visually inspected `Lakes.png` and `Detail.png`: Lakes shows Lake Tahoe, Mono Lake, and Crater Lake; Detail shows Golden Gate Bridge, San Francisco, CA, the description, and Plan Visit. This satisfies the two semantic screen checks.
- AND-017 exits 1 after 5.36 seconds and reports that boot did not finish within 5 seconds.
- AND-018's before/after Grantiva session lists exclude the externally launched emulator, its run passes, and the post-run terminal identity record proves the same external PID/PGID/start/executable and booted serial remained alive until the later targeted force cleanup.
- AND-019 exits 0 and stderr names `:app:assembleFreeDebug`.

## Identity, hashes, and guard disposition

All 373 files listed in `first25-artifact-manifest.json` exist and match their recorded SHA-256 and byte count. All 112 current command identity records inspected bind candidate manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; every listed binary, bundle, archive, and installed-runner expected/actual hash pair matches. No command record reports a timeout cleanup failure.

AND-107's four join hashes resolve exactly: review `fbb1f8288ebfcf66e20063c2cb0e8ed55df85edf67ae56dce0d69dc705cbcf59`, command `c65716ba507766cb286d875175e4f1b7f1a786c4a3a22816b2e67d9d560923e9`, result `1a3c5c5353424cb45cc489fa6a4fb9e2efcad9d20ea21b4255c52c5bed7bb76c`, and report `ee12532738fc052cfae117830db420b7d3f52c9a834371399a747b0675b04606`.

The three BLOCKED dispositions are correctly bounded. AND-002 records installed inventory and invokes no SDK download; it does not overclaim remote image absence. AND-012 is explicitly blocked because global `teardown --all` is prohibited. AND-110 remains blocked as a whole because its literal docs sequence contains that prohibited global leg; its safe examples are only partial joins to separately captured rows. Targeted lifecycle commands use the named owned AVDs/serials, while refusal paths and the blocked global operations avoid protected devices. Nothing in this checkpoint justifies upgrading AND-002, AND-012, or AND-110 to PASS.
