# Android Plan 3 acceptance pass

Date: 2026-10-08. Host: macOS (Darwin 27.2.0). Emulator `Pixel_8_API_35` running as
`emulator-5554`, started by hand (not in Grantiva's ledger). `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`,
`ANDROID_HOME=/Users/kyle/Library/Android/sdk`, platform-tools and emulator on PATH. CLI from
`swift build` at the worktree root (first pass at f54d2c4, resumed at c68efd6, 168a0f2, and 7a7588d); commands run from `examples/android` with
`G=/Users/kyle/Developer/grantiva-cli/.claude/worktrees/android-plan3/.build/debug/grantiva`.
Before the pass: `adb forward --list` empty, `/tmp/grantiva-sessions` empty, no
`~/.grantiva/android/started.json` or `created-avds.json`.

Result: **all steps completed.** Steps 1–4 and 6–10 passed. Step 5 is host-caused: the
emulator's `screenrecord` writes a single frame. Step 11 does not apply: there is no iOS example
in this worktree. The host was left as found.

Acceptance found three branch defects. Each was fixed on this branch and the affected steps
were re-run on the rebuilt CLI:

| Pass | Built at | Stopped at | Defect | Fix |
|------|----------|------------|--------|-----|
| 1 | f54d2c4 | step 4 | Port-0 Android keep-alive sessions ignored | c68efd6 |
| 1 | f54d2c4 | step 4 | Capture settings not restored on Ctrl-C | c68efd6 |
| 2 | c68efd6 | step 7 | Runner from `runner start` exits after about 9 s on Android | 168a0f2 |
| 3 | 168a0f2 | step 7 | `adb shell` swallows the MCP server's stdin | 7a7588d |
| 4 | 7a7588d | — | — | — |

The fourth pass resumed at step 7 and ran to step 12.

## Build (brief step 2) — PASSED

`swift build` → `Build complete!`. `grantiva --help` lists `emulator` between `simulator` and
`hierarchy`:

```
  simulator               Provision, inspect, and tear down managed simulators.
  emulator                Provision, inspect, and tear down Android emulators.
  hierarchy               Dump the UI hierarchy of a booted simulator or
```

## 1. `$G emulator sessions` — PASSED

Exit status: 0.

```
No emulators started by Grantiva are running.
```

## 2. `$G emulator ensure --name Pixel_8_API_35` — PASSED

Exit status: 0. Stdout is exactly `emulator-5554\n` (checked with `od -c`). Stderr:

```
Reused Pixel_8_API_35 (emulator-5554) — Booted
```

## 3. `$G build` — PASSED

Exit status: 0.

```
[grantiva] Building :app:assembleDebug for Pixel_8_API_35...
✓ Build succeeded
  APK: /Users/kyle/Developer/grantiva-cli/.claude/worktrees/android-plan3/examples/android/app/build/outputs/apk/debug/app-debug.apk
  Duration: 9.6s
```

## 4. Keep-alive and hierarchy — PASSED (after c68efd6)

`$G run --keep-alive --ready-file /tmp/grantiva-ready.json &`, with `$!` = 39528 captured. The
ready file appeared and the run printed:

```
  GrantivaAgent keep-alive: session=39615-1791514373359777000
  /tmp/grantiva-sessions/39615-1791514373359777000.grantiva
    Press Ctrl-C to release.
```

`$G hierarchy > hier.xml` exited 0 with 31062 bytes. `package="dev.grantiva.example"` is on 22
lines and there are 47 `bounds=` attributes. Start of the file:

```
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<hierarchy index="0" class="hierarchy" rotation="0" width="1080" height="2400">
  <android.widget.FrameLayout index="0" package="com.android.systemui" class="android.widget.FrameLayout" ...
```

`$G hierarchy --format json` exited 0. The output begins with `{` and contains
`"platform" : "android"`. Frames are in dp: the status bar container is `"width" : "411"` on the
1080 px wide screen.

`$G runner dump-hierarchy --format tree` exited 0:

```
[hierarchy]
  [android.widget.FrameLayout]
    [android.widget.FrameLayout] id="com.android.systemui:id/status_bar_launch_animation_container"
...
                    [android.view.View] label="Details"
                    [android.widget.TextView] label="Details" value="Details"
```

While the session was held, `adb forward --list` showed only the runner's own forward:

```
emulator-5554 localfilesystem:/tmp/uia2-emulator-5554.sock tcp:6790
```

None of the CLI's `tcp:<n> tcp:6790` forwards remained. Controller ruling: the runner's socket
forward is expected while a session is held, and the "forward list empty" check applies once the
session ends.

`kill -INT 39528`, then waited for the process to exit. The log shows
`[grantiva] received SIGINT — releasing simulator and reaping child processes`. Afterwards:
- `adb forward --list` was empty.
- `/tmp/grantiva-sessions` was empty.
- `.grantiva/android-settings-emulator-5554.json` was gone (`.grantiva` held only `captures`).
- The device settings were back to the saved values: `window_animation_scale` 1.0,
  `transition_animation_scale` 1.0, `animator_duration_scale` null, `sysui_demo_allowed` 0,
  `user_rotation` 0, `accelerometer_rotation` 0.

### First pass (f54d2c4): two defects, found and fixed on this branch (c68efd6)

`$G run --keep-alive --ready-file /tmp/grantiva-ready.json &` (pid 31933). The ready file
appeared (`"status" : "passed"`, flow `flow` passed) and the run printed:

```
  GrantivaAgent keep-alive: session=32077-1791513854079231000
  /tmp/grantiva-sessions/32077-1791513854079231000.grantiva
    Press Ctrl-C to release.
```

The session directory held both files, and the runner (pid 32077) was alive:

```
/tmp/grantiva-sessions/32077-1791513854079231000.grantiva:
{
  "version": "1.1.18-grantiva.7",
  "sessionId": "32077-1791513854079231000",
  "createdAt": "2026-10-08T19:44:14.079245-07:00",
  "pid": 32077,
  "port": 0,
  "outputDir": "/var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-report-ED3517A7-EFC0-4409-A949-45F4B8300D87"
}
/tmp/grantiva-sessions/32077.owner.json:
{"createdAt":"2026-10-09T02:43:56Z","grantivaPid":31933,"runnerPid":32077,"udid":"emulator-5554"}
```

`$G hierarchy > hier.xml` — exit status 1, empty file:

```
Error: Invalid argument: No keep-alive session found. Start one with `grantiva run --keep-alive` first.
```

`$G hierarchy --format json` — same error. `$G runner dump-hierarchy --format tree` — exit 1:

```
Error: Invalid argument: No active runner session. Start one with 'grantiva runner start' or `grantiva run --keep-alive`, or pass --port.
```

`adb forward --list` while the run was held (the runner's own forward, not one of the CLI's):

```
emulator-5554 localfilesystem:/tmp/uia2-emulator-5554.sock tcp:6790
```

Defect 1 (fixed in c68efd6: the store now accepts port 0). `KeepAliveSessionStore.loadRunnerSession`
(`Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:179`) requires `port > 0`, so it
drops the runner's Android session file, which carries `"port": 0` by design (the runner does
not proxy UIAutomator2). `HierarchyCommand.runAndroid` and `DumpHierarchyCommand.resolveTarget` (`Sources/GrantivaCLI/DriverCommand.swift:631`)
both say they expect a port of 0 on Android, but they never see the session because
`liveSessions()` filtered it out. The tests write non-zero ports
(`HierarchyCommandTests.swift:83`, `KeepAliveSessionStoreTests.swift:123`), so no test
covers an Android keep-alive session.

`kill -INT 31933`, then waited for it to exit. The run printed
`[grantiva] received SIGINT — releasing simulator and reaping child processes` and
`Releasing GrantivaAgent session...` and exited. After that, `adb forward --list` was empty and
`/tmp/grantiva-sessions` was empty, but **`.grantiva/android-settings-emulator-5554.json` was
still there** and the emulator was left in capture settings (animation scales `0`,
`sysui_demo_allowed` `1`). Defect 2 (fixed in c68efd6: `grantiva run` registers a SignalRelay cleanup that restores capture settings and cleans orphans). `SignalRelay.handle` calls `exit()` once its
registered cleanups have run, and `RunnerSession.runWithStatusBarCleanup` restores the
settings only after the operation returns. So a SIGINT'd `run --keep-alive` on Android never
restores them; the next run's `restoreIfCrashed` is the only recovery. That code predates
Plan 3 (e5ab959).

Host restored by hand from the snapshot (`window_animation_scale` 1.0,
`transition_animation_scale` 1.0, `animator_duration_scale` deleted, `sysui_demo_allowed` 0,
rotation 0/0, demo mode exited), and the snapshot file removed.

## 5. `$G record --duration 5 --frames-at 0,1000,3000` — HOST-CAUSED (emulator screenrecord)

Exit status: 1.

```
Error: Grantiva recording ended at 0ms before requested frame 3000ms exited with code 1
```

`.grantiva/recordings/recording.mp4` was written (19916 bytes, 1080×2400). It holds a single
frame, and its duration is 0:

```
$ ffprobe -show_entries format=duration:stream=nb_frames,width,height recording.mp4
width=1080
height=2400
nb_frames=1
duration=0.000000
```

The screen was static, so I repeated the command while swiping. The output was the same
(1 frame, duration N/A). Then I ran `adb shell screenrecord --time-limit 5 /sdcard/probe.mp4`
by hand, without Grantiva, while pressing Home and relaunching the app twice. It also produced
one frame (19917 bytes, duration N/A).

This emulator's `screenrecord` records only the first frame. The guest renderer is
`ro.hardware.egl=emulation` (host GPU). So this is a host problem, not a branch defect. The CLI
did what it should with that input: it pulled the file and refused frames past the recorded end
with a clear error. No PNGs were extracted, so the 1080×2400 frame check could not run.
Controller ruling: this is host-caused, and refusing to extract frames from a broken video is
the correct behaviour.

The command works end to end without `--frames-at`. At 168a0f2, `$G record --duration 5` exited 0:

```
Recording: .grantiva/recordings/recording.mp4
Frame report: /Users/kyle/Developer/grantiva-cli/.claude/worktrees/android-plan3/examples/android/.grantiva/recordings/recording.json
```

It wrote `recording.mp4` (28402 bytes) and `recording.json` with `"frames" : [ ]`,
`"requestedDurationSeconds" : 5`, and `"udid" : "emulator-5554"`.

## 6. `$G record --duration 200` — PASSED

Exit status: 1.

```
Error: Invalid argument: Android recordings are capped at 180 seconds per file (screenrecord --time-limit); --duration 200.0 is too long.
```

## 7. Runner session and MCP — PASSED (after 7a7588d)

### Fourth pass (7a7588d)

`$G runner start --detach` exited 0:

```
Starting runner...
  Application ID: dev.grantiva.example
  Device: Pixel_8_API_35 (emulator-5554)
Runner started (detached)
  UIAutomator2 port: 58556
  PID:      54327
  Log:      /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791515444.log
  Session:  .grantiva/session.json
```

`$G runner dump-hierarchy --format tree | head -5` exited 0:

```
[hierarchy]
  [android.widget.FrameLayout]
    [android.widget.FrameLayout] id="com.android.systemui:id/status_bar_launch_animation_container"
    [android.widget.FrameLayout] id="com.android.systemui:id/status_bar_container"
      [android.widget.FrameLayout] id="com.android.systemui:id/status_bar"
```

`python3 -I -u mcp-probe.py "$G"` was run with the app on its Home screen. Script variants are
described below. Output:

```
{'name': 'grantiva', 'version': '2.0.1'}
tools: 22
grantiva_context ok [Config] |   platform: android |   module: app |   variant: debug |   application_id: dev.grantiva.example |   emulator: Pixel_8_API_35 |   screens: 3 |  | [Emulator] |   name: P
grantiva_emulator_list ok Name | Serial | State | Pixel_8_API_35 | emulator-5554 | Booted
grantiva_screenshot ok Screenshot saved to .grantiva/mcp-screenshot.png
grantiva_tap ok Tapped on "Details". Updated hierarchy: | { |   "children" : [ |     { |       "children" : [ |         { |           "children" : [ |  |           ], |           "clickable" : f
grantiva_a11y_check ok Found 2 accessibility violation(s): | [ |   { |     "message" : "Interactive element of type android.view.View has no accessibility label or name.", |     "rule" : "mis
grantiva_swipe ok Swiped up. Updated hierarchy: | { |   "children" : [ |     { |       "children" : [ |         { |           "children" : [ |  |           ], |           "clickable" : false, |     
```

- `grantiva_context` includes `[Emulator]` / `name: Pixel_8_API_35` / `serial: emulator-5554`, and
  `[Runner Session]` / `pid: 54327` / `driver_port: 58556` / `udid: emulator-5554`.
- `.grantiva/mcp-screenshot.png` is 1080×2400 (`sips`).
- The hierarchy returned by `grantiva_tap` contains `"Line three."` twice.
- `grantiva_a11y_check` returned a JSON list. It reported two `missing_label` violations, both
  on `android.view.View`:

  ```
  [
    { "message" : "Interactive element of type android.view.View has no accessibility label or name.", "rule" : "missing_label", "type" : "android.view.View" },
    { "message" : "Interactive element of type android.view.View has no accessibility label or name.", "rule" : "missing_label", "type" : "android.view.View" }
  ]
  ```

Probe notes. The brief's script indexes `["result"]` and prints only the first 160 characters.
So the final run used `mcp-probe-full.py`: the same calls, but it writes each tool's full text to
a file and prints a JSON-RPC error instead of raising `KeyError`. Two earlier runs in this pass
got `grantiva_tap` → JSON-RPC error
`Internal error: Element not found: "Details". Run grantiva ui a11y to inspect the tree.`, and
they were not product defects:
- The first came seconds after `runner start` had relaunched the app.
- The second came 3 s after I force-stopped and relaunched the app by hand.

In the second case `.grantiva/mcp-screenshot.png` shows the app's splash screen, and
`grantiva_a11y_check` in the same run found no violations, because the app tree was not up yet.
Once the app was on Home, every call passed, as shown above.

While the session was held, before `runner stop`:

```
$ ls -A /tmp/grantiva-sessions
54327-1791515459034651000.grantiva
$ adb forward --list
emulator-5554 localfilesystem:/tmp/uia2-emulator-5554.sock tcp:6790
emulator-5554 tcp:58556 tcp:6790
```

The MCP server removed its own forward on exit; only the runner's forward and the session's
forward remained.

`$G runner stop` exited 0 and printed `Runner stopped (pid 54327)`. After it:
- `/tmp/grantiva-sessions` was empty: the keep-alive `.grantiva` file is gone.
- `ps -p 54327` found nothing.
- `adb forward --list` was empty.
- `adb shell pidof io.appium.uiautomator2.server` printed nothing.

### Third pass (168a0f2): MCP stdin consumed by adb, found and fixed on this branch (7a7588d)

`$G runner start --detach` exited 0:

```
Runner started (detached)
  UIAutomator2 port: 57371
  PID:      46895
  Log:      /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791514809.log
  Session:  .grantiva/session.json
```

About 10 s later the runner was still alive. Its log ended with
`GrantivaAgent keep-alive: session=46895-1791514819059008000` / `Press Ctrl-C to release.`, and
`/tmp/grantiva-sessions/46895-1791514819059008000.grantiva` existed.

`$G runner dump-hierarchy --format tree | head -5` exited 0:

```
[hierarchy]
  [android.widget.FrameLayout]
    [android.widget.FrameLayout] id="com.android.systemui:id/status_bar_launch_animation_container"
    [android.widget.FrameLayout] id="com.android.systemui:id/status_bar_container"
      [android.widget.FrameLayout] id="com.android.systemui:id/status_bar"
```

`python3 -I -u mcp-probe.py "$G"` (the brief's script) hung. It printed nothing, not even the
`initialize` result, and was still waiting after 60 s. The UIAutomator2 server was healthy
through the forward the whole time:

```
$ curl -s http://127.0.0.1:57371/status
{"sessionId":"None","value":{"build":{"version":"9.11.1","versionCode":253},"message":"UiAutomator2 Server is ready to accept commands","ready":true}}
$ curl -s http://127.0.0.1:57371/sessions
{"sessionId":"None","value":[{"id":"e99d82ee-3ccc-453f-a03e-15d201b244f7",...}]}
```

`sample` of the `grantiva mcp` process showed it idle in `StdioTransport.readLoop()` → `read`. So
the server was running and waiting for input, while the client was waiting for the `initialize`
reply.

To isolate the cause, I used a debug client that pumps stdout and stderr on threads:
- Sending `initialize` 3 s after launching `grantiva mcp` gets an immediate reply:
  `{"id":1,"jsonrpc":"2.0","result":{"capabilities":...,"serverInfo":{"name":"grantiva",...`.
- Sending `initialize` immediately gets no reply within 15 s.

Diagnosis:
- `GrantivaMCPServer.run()` calls `device.attachDriver(...)` before `server.start(transport:)`.
- On Android, `attachDriver` runs `adb ... shell wm size` and `adb ... shell wm density`
  (`displayGeometry`) through `GrantivaCore.shell` (`Sources/GrantivaCore/Shell.swift`).
- `shell` creates a `Process` without setting `standardInput`, so it inherits the MCP server's
  stdin. `adb shell` forwards stdin to the device, so a request that is already in the pipe is
  read and discarded by `adb`.
- MCP clients send `initialize` as soon as they spawn the server, so a real agent config hits
  this every time.
- The same inheritance applies to every `adb shell` a tool call runs, such as swipe and tap
  input, while further requests are queued.
- iOS does not hit this, because no `adb shell` runs in the server.

Fixed in 7a7588d: every `shell()` subprocess now gets `/dev/null` as stdin.

`$G runner stop` printed `Runner stopped (pid 46895)` and exited 0. After it:
- `/tmp/grantiva-sessions` was empty. The keep-alive session file
  `46895-1791514819059008000.grantiva` is gone.
- `ps -p 46895` found nothing.
- `adb forward --list` was empty.
- `adb shell pidof io.appium.uiautomator2.server` printed nothing.

### Second pass (c68efd6): runner exits after ~9 s, found and fixed on this branch (168a0f2)

`$G runner start --detach` exited 0:

```
Starting runner...
  Application ID: dev.grantiva.example
  Device: Pixel_8_API_35 (emulator-5554)
Runner started (detached)
  UIAutomator2 port: 56495
  PID:      41277
  Log:      /var/folders/jv/76l6crmx6nl3hf150gzry_ym0000gn/T/grantiva-runner-1791514471.log
  Session:  .grantiva/session.json
```

`.grantiva/session.json` contained
`{"wdaPort":56495,"bundleId":"dev.grantiva.example","startedAt":813207275.73121,"udid":"emulator-5554","pid":41277}`.
`adb forward --list` showed `emulator-5554 tcp:56495 tcp:6790` beside the runner's socket forward.

`$G runner dump-hierarchy --format tree | head -5` printed the tree (`[hierarchy]`,
`[android.widget.FrameLayout]`, …).

`python3 -I mcp-probe.py "$G"` (the brief's script) failed before `initialize` returned:

```
Error: Invalid argument: No active runner session at /Users/kyle/Developer/grantiva-cli/.claude/worktrees/android-plan3/examples/android/.grantiva/session.json. Start one with 'grantiva runner start' or `grantiva run --keep-alive`.
server closed
```

By then the runner pid 41277 had exited. `ps -p 41277` found nothing. The runner log shows it
ran the session flow to completion and exited:

```
  [1/1] session-flow (session-flow.yaml)
    ⚠ launchApp (6.1s)
    ✓ waitForAnimationToEnd (2.8s)
✓ session-flow 9.0s
...
  ✓ Tests completed. Generating reports...
  Built by Grantiva
```

Diagnosis:
- `RunnerStart` (`Sources/GrantivaCLI/DriverCommand.swift:159-174`) keeps the runner alive with a
  flow of `launchApp` plus `waitForAnimationToEnd: timeout: 3600000`.
- On Android, the runner's `waitForAnimationToEnd` returns as soon as the screen settles (2.8 s
  here). It does not wait for the timeout. The runner then exits, about 9 s after the start.
- `runner start` records `session.json` as soon as the UIAutomator2 session attaches, so
  `dump-hierarchy` works only inside that window.
- The MCP server then sees `session.isAlive == false` and refuses to start.
- The runner arguments don't include `--keep-alive` (`runnerArguments(platform:deviceID:flowPath:)`
  adds only the global flags, `test`, and the flow), so nothing else holds the session.

Fixed in 168a0f2: `runner start` passes `--keep-alive` to the runner on Android, so the session
is held until `runner stop` sends SIGINT.

`$G runner stop` printed `Runner stopped (pid 41277)` and exited 0. After it, `adb forward --list`
and `adb shell pidof io.appium.uiautomator2.server` were both empty.

## 8. Emulator lifecycle on a second AVD — PASSED

`$G emulator ensure --name Grantiva_Plan3_Test --headless` exited 0 after 17 s (20:12:21 →
20:12:38). The system image was already installed, so nothing was downloaded. Stdout is exactly
`emulator-5556\n` (`od -c`). Stderr:

```
Creating AVD Grantiva_Plan3_Test
Booting AVD Grantiva_Plan3_Test as emulator-5556
Created Grantiva_Plan3_Test (emulator-5556) — Booted
```

`$G emulator sessions` exited 0:

```
Grantiva-started emulators (1):
  emulator-5556 (Grantiva_Plan3_Test) — pid 55956 running, adb: device
```

`$G emulator teardown --serial emulator-5554` exited 1 (no `--force`):

```
Error: Invalid argument: emulator-5554 was not started by Grantiva (see `grantiva emulator sessions`). Pass --force to kill it anyway.
```

`$G emulator delete --name Grantiva_Plan3_Test` exited 1:

```
Error: Invalid argument: AVD "Grantiva_Plan3_Test" is running as emulator-5556. Run `grantiva emulator teardown --serial emulator-5556` first.
```

`$G emulator teardown --serial emulator-5556` exited 0 and printed
`Killed emulator-5556 (Grantiva_Plan3_Test).`. Afterwards `adb devices` listed only
`emulator-5554	device`, and `$G emulator sessions` printed
`No emulators started by Grantiva are running.` (exit 0).

`$G emulator delete --name Pixel_8_API_35` exited 1:

```
Error: Invalid argument: AVD "Pixel_8_API_35" is running as emulator-5554. Run `grantiva emulator teardown --serial emulator-5554` first.
```

`$G emulator delete --name Grantiva_Plan3_Test` exited 0 and printed
`Deleted AVD Grantiva_Plan3_Test`. Afterwards `emulator -list-avds` listed only `Pixel_8_API_35`,
and `~/.grantiva/android/created-avds.json` was `[]`.

## 9. `$G ci run` — PASSED

Exit status: 1.

```
Error: Invalid argument: Android baselines are local only until the Grantiva backend supports platforms; use local baselines
```

## 10. `swift test` — PASSED

From the worktree root at 7a7588d (plus the uncommitted doc edits). Exit status: 0.
**981 tests, 0 failures:**

| Bundle | Tests |
|--------|-------|
| GrantivaMCPTests | 101 |
| GrantivaCoreTests | 434 |
| GrantivaCLITests | 330 |
| GrantivaAPITests | 116 |

```
Test Suite 'All tests' passed ...
	 Executed 434 tests, with 0 failures (0 unexpected) in 23.177 (23.207) seconds
```

## 11. iOS smoke — NOT APPLICABLE

There is no iOS example in this worktree (`examples/` holds only `android`), so `run --no-build`
on iOS was not exercised.

## 12. Host state at the end — PASSED

```
$ adb devices
List of devices attached
emulator-5554	device
$ adb forward --list
(empty)
$ adb shell pidof io.appium.uiautomator2.server
(empty)
$ ls -A /tmp/grantiva-sessions
(empty)
$ cat ~/.grantiva/android/started.json
[]
$ cat ~/.grantiva/android/created-avds.json
[]
$ emulator -list-avds
Pixel_8_API_35
$ adb shell settings get global {window_animation_scale,transition_animation_scale,animator_duration_scale,sysui_demo_allowed}
1.0 / 1.0 / null / 0
```

No `grantiva-runner`, `grantiva mcp`, or `Grantiva_Plan3_Test` processes are left. The ignored
`examples/android/.grantiva` scratch output was removed; it was absent before the pass.
