# Runner cleanup removes an unrelated local forward matching the remote driver port

Status: CONFIRMED during Task8; owner runner Android lifecycle follow-up. CLI fb7af9d1, runner ff68658f /1.1.28-grantiva.14.

StopUIAutomator2 unconditionally removes local tcp:6790 after cleaning its recorded socket/local port. A remote/device port number is not proof of local-forward ownership. The analogous StopDeviceLabDriver cleanup unconditionally removes local DeviceLabDriverPort. Neither callback may delete an unrelated forward by this number.

Live isolated proof: findings/evidence/round4-smoke/03-lifecycle/unrelated-forward-6790-repro. Controller verified owned smoke4-android/emulator-5580, no existing tcp6790 forward across devices, created no-rebind tcp6790→tcp16790 as unrelated control, recorded before inventory. Frozen CLI healthy stock exited0 (8steps passed), but control forward was absent afterward. Exact cleanup inventory retained. No owner forward was touched.

Acceptance:
- Production unit regression reproduces unconditional removal of an unowned local port matching remote driver port, then passes for both UIAutomator2 and analogous DeviceLab cleanup.
- Cleanup removes only its tracked owned socket/allocated local port; remove unconditional remote-number local-port deletion. Preserve required owned transport cleanup and platform support; no remove-all fallback.
- Live owned Android control tcp6790→tcp16790 survives healthy stock, foreground ready SIGINT, and normal foreground stop; owned runner/CLI forwards and sessions disappear after each. Preserve all original lifecycle/crash/gesture/optional acceptance.
- Focused uncached Go tests/vet, independent review, CI, merged runner, fresh correctly versioned both-architecture CLI repack, full CLI tests/CI and exact final candidate smoke pass. No tag/release.
