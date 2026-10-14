# CLI-082 candidate5 clause assessment

Verdict: **PASS**.

Expected: SDK check is a warning naming the variable: `... (ANDROID_HOME=/nonexistent has no platform-tools/adb; unset or fix it)`; same for `ANDROID_SDK_ROOT` (brief C23)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-082-run-1/android-home.command.json`, `CLI-082-run-1/android-sdk-root.command.json`.
