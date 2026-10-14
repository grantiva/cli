# CLI-080 candidate5 clause assessment

Verdict: **PASS**.

Expected: Falls back to `ANDROID_SDK_ROOT`, then `~/Library/Android/sdk` (docs/android-environment.md:15-16)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-080-run-1/root-fallback.command.json`, `CLI-080-run-1/home-fallback.command.json`.
