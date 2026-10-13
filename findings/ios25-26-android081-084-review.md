# iOS attempts 25–26 and Android 081–084 review

Scope: exact matrix clauses and retained current-round artifacts only. Candidate source baseline is `release-main` at `8f2cff67`. No device/build commands were run.

## Findings

### Important — B-C03.2 is only partially covered

`cov3-ios-attempt25` strongly supports B-C03.1 and the same-platform/different-project half of B-C03.2. Project A's context attaches to PID 53850 and exact U1; project B reports no active session and explicitly says one session from another project directory **or platform** was ignored; `a-still-live.json` proves B did not disrupt A; the owning A project stops it.

The binding B-C03.2 row is platform `both` and requires attachment only when both project directory **and platform** match. This runtime attempt uses iOS configuration for both A and B. Its generic diagnostic does not prove the alternate-platform rejection branch, and no Android runtime counterpart is cited in the result. B-C03.2 should remain partial unless joined to retained Android same-project attachment plus a real mismatched-platform session-store/runtime observation. B-C03.1 is supported as graded.

### Important — AND-083 lacks the competing config input

`AND-081-084-exact-rerun1/commands.txt`, `override-start.json`, `session-after-override.json`, and `override-stop.json` prove that explicit `--application-id x.y --emulator cov3-android` produced application ID `x.y` on `emulator-5554`. They do not alone prove that flags **won over config**.

The evidence directory preserves the controller script but not the project `grantiva-android.yml` (or a checksum/content snapshot of it) at execution time. The frozen script merely `cd`s to `$P`; it neither records nor asserts different configured application/emulator values before start. The row needs the competing config values preserved from the execution environment. Until joined to such a contemporaneous capture, AND-083 is an explicit-flags success, not a precedence proof.

## Supported grades

### iOS attempt 26

- **IOS-021:** explicit `Landmarks (UI Testing)` and exact U1 build exits 0.
- **IOS-022:** install/launch reports the expected running application and data container.
- **IOS-023:** JSON has every required field and exact name/UDID. `pre-no-launch-terminate.*` establishes the precondition; the immediate launchctl inventory contains no `com.kylebrowning.Landmarks` process.
- **IOS-024:** both the absolute spaced path and relative `relative-parent/relative Derived Data` resolve under the attempt cwd. JSON app paths and `derived-data-inventory.txt` place products under the requested trees.
- **IOS-025:** config preserves `OTHER_SWIFT_FLAGS=-DROUND3`; the flag redirects Derived Data to `flag-derived-data`; retained Xcode build-request content contains `OTHER_SWIFT_FLAGS : -DROUND3`. This covers precedence and retention of the other setting.
- **IOS-026:** exit 1 clearly names `NoSuchScheme` and says the Landmarks project lacks it.
- **IOS-027:** the omitted-scheme error is nonzero, says `No scheme specified`, and lists both project schemes.
- **IOS-028:** name and UDID inputs both resolve to `cov3-ios-26` / exact U1 and exit 0.

### Android lifecycle

- **AND-081:** tree, JSON, and XML are nonempty views of the same live Landmarks hierarchy; each contains the same identifying application content.
- **AND-082:** stop records exact PID/port/serial, the runner PID is dead, the session file is removed by the script guard, and both Android forwards present during the session are absent afterward. This is adequate observable proof of runner/UIAutomator transport teardown.
- **AND-084:** the original PID 54010 is proven dead before its exact record is restored; start replaces it with PID 54330 on `emulator-5554`, then final stop succeeds and removes the session.

## Verdict

Approve B-C03.1, IOS-021 through IOS-028, AND-081, AND-082, and AND-084. Hold B-C03.2 as partial and AND-083 as unsupported pending the precise missing evidence above.
