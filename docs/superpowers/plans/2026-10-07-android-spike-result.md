# Android keep-alive spike result, 2026-10-07

Runner: 1.1.18-grantiva.7 binary with the android drivers stamp (`~/.grantiva/runner/version` reads `1.1.18-grantiva.7+android-drivers`, commit 37fb04c). Emulator: Pixel_8_API_35, serial emulator-5554.

Session file appeared: yes. Port: 0. The file is `/tmp/grantiva-sessions/<pid>-<nanos>.grantiva` with `"port": 0`. The runner process holds no TCP listener (lsof shows only unix sockets).
GET /source: no response; curl to `127.0.0.1:0` fails to connect (HTTP 000, curl exit 7).
GET /source?format=json: no response; HTTP 000, curl exit 7.
GET /status: no response; HTTP 000, curl exit 7.
UIAutomator2 direct on 6790 while session held: 200. After `adb -s emulator-5554 forward tcp:6790 tcp:6790`, `/wd/hub/status` returned `{"sessionId":"None","value":{"build":{"version":"9.11.1",...},"ready":true}}`. `GET /sessions` listed the runner's session (`d29f964c-...`), and `GET /wd/hub/session/<id>/source` returned 200 with a JSON-wrapped `<hierarchy ...>` XML containing 89 `bounds=` attributes.
After Ctrl-C: sessions dir empty yes; forwards cleared yes. The runner's teardown cleared both its own forward and the manual `tcp:6790` forward, so it looks like it removes every forward for the device.

Decision for Plan 3: "runner does not proxy UIA2; Android DriverClient forwards 6790 itself and hierarchy reads /wd/hub/session/<id>/source".

## Other observations for Plan 3

- The runner finds `drivers/android` under `MAESTRO_RUNNER_HOME`, which defaults to the current working directory. The first run, started from `/tmp/spike`, failed with `drivers directory not found: /tmp/spike/drivers/android`. The second run set `MAESTRO_RUNNER_HOME=~/.grantiva/runner` and passed. The CLI must set that variable, or the working directory, when it launches the runner for Android.
- The runner talks to UIAutomator2 through an adb forward from a host unix socket (`/tmp/uia2-emulator-5554.sock`) to device `tcp:6790`, not through a host TCP port. That socket answers WebDriver requests too (`curl --unix-socket /tmp/uia2-emulator-5554.sock http://localhost/status` returned 200), but the runner deletes it on exit.
- The UIA2 session id does not appear in the `.grantiva` file. To find it, call `GET /sessions` (over the unix socket it returned exactly one session; `/wd/hub/` prefixed and unprefixed paths both answered for `status`).
- Because the runner's teardown clears every forward for the device, a forward the CLI adds itself only lasts while the runner session does.
- The flow passed unchanged on API 35: `assertVisible: "Network & internet"` matched, and the 30 s default driver start timeout was enough.
