# D2-13 exact decoded JSON join

D2-13 is fully supported on both platforms by current-round evidence.

## iOS

- `cov3-ios-attempt62/start-json.out`: `status: started`; numeric `pid` and `port`; `platform: ios`; `bundleId`, deprecated equal `bundle_id`, and `udid`; detached `log` path.
- `cov3-ios-attempt21/04-start-already-running.out` (also corroborated by attempt 78c): `status: already_running`; numeric `pid`/`port`; the same platform and identity keys; no `log` on the already-running response.
- `cov3-ios-attempt62/stop-json.out`: `status: stopped`; numeric `pid`/`port`; platform, bundle aliases, and UDID retained.
- `cov3-ios-attempt62/stop-no-session-json.out`: `status: not_running` and no invented process identity.

## Android

- `X013-X015-X017-android-rerun1/json/start.json`: `status: started`; numeric `pid`/`port`; `platform: android`; `applicationId`, deprecated equal `bundle_id`, `serial`, deprecated equal `udid`, and detached `log`.
- `AND-126-127-exact-rerun1/already.json`: `status: already_running`; numeric `pid`/`port`; the same platform and identity keys; no `log`.
- `X013-X015-X017-android-rerun1/json/stop.json`: `status: stopped`; numeric `pid`/`port`; platform, application aliases, serial, and deprecated UDID retained.
- `X013-X015-X017-android-rerun1/json/no-session-stop.json`: `status: not_running` and no invented process identity.

Every observed status belongs to the matrix vocabulary. No retained command produced `exited`; the row asks to record which condition yields it, so the honest record is that none of these conditions did. The separate dead-runner stop capture also returns `stopped` with `alreadyExited: true`, confirming that `exited` is not the candidate's dead-runner spelling. This absence is not an untested required branch and does not weaken the documented four-condition coverage.

