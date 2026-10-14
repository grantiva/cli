# Android runtime 051–075 static execution plan

Status: **prepared only**. Reservation `android-runtime-051-075.prepared.json` is not active. No command in this plan has run.

The exact 37-key order is AND-114–121, AND-145, AND-137, AND-051–064, AND-122, AND-065–075, AND-123. Every command uses the frozen candidate-4 CLI and runner homes, explicit JDK/SDK environment, real HOME, row-local report/ready paths, and exact authenticated campaign AVD serials. Before each lifecycle mutation, bind PID, start time, executable, argv, PGID/session, serial, and AVD name. Preserve the frozen APK for unrelated runtime rows.

## Device-selection and flow semantics

1. AND-114: stop the primary, remove `emulator:` in a row-local config, prove no running emulator, and retain the no-boot failure listing AVDs.
2. AND-115: use the approved detached emulator helper to hold the primary in a genuine booting state; bind it in a second tool call, then run without `emulator:` and prove wait-and-run behavior.
3. AND-116/117: use coverage flows 13 and 11/12 to prove argument/environment merge and header→step→CLI precedence, retaining UI assertions and exact logcat extras.
4. AND-118: use a no-device narration fixture and reject any empty resolved/boot serial.
5. AND-119/120: create distinct screen failure/slow and combined screens+flows fixtures; retain reports, snapshot assets, continuation, and 30-second timing.
6. AND-121: run the literal runner-only `back` flow.
7. AND-145: snapshot demo mode, animation scales, rotation, and settings journal before/during/after the allowed-settings run; require restoration.
8. AND-137: run plain/quiet/verbose on the same passing flow and quiet on the exact-negative flow; compare decoded stable results and retain mode-specific streams.

## Keep-alive, hierarchy, concurrency, and forwarding

1. AND-051 starts an owned keep-alive run with an exclusive terminal journal and proves its UIAutomator2 session remains until targeted SIGINT.
2. Create/authenticate secondary generation only inside the active window. AND-052 and AND-056 use two live sessions and prove newest/default versus explicit-serial selection.
3. AND-053–055 capture XML, formatted JSON with dp frames, and JSON envelope from the same untouched app tree.
4. AND-057 records exact forwards before/during/after a bounded hierarchy command. AND-058 targets an authenticated killed keep-alive owner and proves the dead session is ignored without signaling an unknown PID.
5. AND-059/060 capture targeted SIGINT cleanup, ready interruption, exact PID/session/sidecar/UIA/forward absence, restored settings, and absence of failure screenshots.
6. AND-061 waits for the ready record then invokes hierarchy before interrupting and cleaning only the owned session.
7. AND-062 runs distinct primary/secondary sessions concurrently. AND-063 starts a second run against the already-owned serial and retains the exact fast ownership diagnostic and absence of a failure screenshot.
8. AND-064 installs one explicit unrelated forward on the other serial, runs and cleans the target serial, and proves only target forwards were removed.
9. AND-122 executes the three documented keep-alive/hierarchy examples literally with allocated names and preserves their stated outputs.

## Settings and logs

1. AND-065–068 serialize settings observations. Capture baseline values and journal, during-run demo/scale/portrait state, normal restoration, then one authenticated kill-9 interruption and the next-run recovery. Never signal by pattern.
2. AND-069/070 are `n/a` with exact no-physical-device inventory; do not substitute an emulator or run the commands.
3. AND-071/072 prove UID-scoped logs and tag implication. AND-073 runs none/default/info/debug separately and compares retained line sets (`*:I` for the first three, `*:D` for debug).
4. AND-074 retains parser rejection of the iOS-only predicate name before device work.
5. AND-075 exercises success, failure, and authenticated SIGINT endings and proves no row-owned adb logcat PID remains after each.
6. AND-123 injects a uniquely marked pre-run log line, records device time without clearing the buffer, runs `--logs`, and proves the earlier marker is absent.

## Joins and return state

The proposed cross-slice join map was read but does not directly grade any of these 37 keys. Later B4 Android keys may adopt only the explicitly listed candidate-4 packages after clause-by-clause verification.

Return with the frozen APK restored on the primary, secondary retired unless the next active reservation explicitly retains it, every row-owned worker/session/forward/lease absent, compiler processes absent, protected Pixel config unchanged, and exact primary identity plus adb/ledger inventories recorded.
