# X-015 and Android config-contract review

## X-015: supported

iOS evidence is `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt83/sessions.out`. The isolated scratch runner home contains exactly one Grantiva-managed simulator record. It includes `name`, `udid`, `sessionId`, `ownerPID`, `state`, `bootedByGrantiva`, `ephemeral`, and ISO-8601 UTC `acquiredAt` (`2026-10-13T08:39:33Z`). The harness validates one record against both retained ledger files, checks the timestamp parser and UUID form, and deletes only its exact new device.

Android evidence is `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/X013-X015-X017-android-rerun1/text/sessions.json`. It likewise contains exactly one device record, with `avd`, `serial`, `pid`, `processAlive`, `adbState`, and ISO-8601 UTC `startedAt` (`2026-10-13T05:43:27Z`).

The shapes are appropriately platform-specific but comparable: human device identity, platform identifier, owning process/liveness state, and a stable UTC timestamp. X-015 does not require identical key names. The fresh-home isolation on iOS is justified because it prevents unrelated managed devices from entering the one-device input while the exact owned device is validated and safely removed. No gap remains for X-015.

## B-D01.1 Android: supported

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B-D01.1-hierarchy-json-alias-rerun1/` exercises both `hierarchy` and `runner dump-hierarchy` on a live owned keep-alive session. For each, `--json` and `--format json` exit 0, parse as JSON, and are byte-identical. Both `--json --format xml` controls exit 64 during argument validation with the retained conflict/remedy assertion. The runner and cleanup exit 0. The current pass is supported.

## B-C11.3 Android: supported

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B-C11.3-configless-tools-rerun1/` uses one MCP server rooted at an empty directory. Build, run, and VRT capture return `isError` naming the exact missing `grantiva-android.yml` path and initialization remedy. Emulator list and explicit boot remain usable without config; boot safely reuses the owned AVD. All requests complete and the before/after ADB inventories are unchanged. This satisfies the Android platform half; it does not by itself establish the separate iOS half.
