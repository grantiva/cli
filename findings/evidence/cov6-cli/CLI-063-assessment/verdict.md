# CLI-063 candidate5 clause assessment

Verdict: **PASS**.

Expected: Each parses; failure only at device resolution (README:172)

Fresh candidate5 commands retain exact identity, argv, cwd, exit and raw streams. Explicit review confirms the init/doctor/help/Maestro parser behavior reaches the required result before any compiler or live-device action. Evidence: `CLI-063-run-1/launchApp.command.json`, `CLI-063-run-1/swipe-from.command.json`, `CLI-063-run-1/stopApp.command.json`, `CLI-063-run-1/tapOn.command.json`, `CLI-063-run-1/killApp.command.json`, `CLI-063-run-1/swipe-direction.command.json`, `CLI-063-run-1/scrollUntilVisible.command.json`, `CLI-063-run-1/runFlow-map.command.json`, `CLI-063-run-1/doubleTapOn.command.json`, `CLI-063-run-1/extended-not.command.json`, `CLI-063-run-1/swipe-start-end.command.json`, `CLI-063-run-1/assertVisible.command.json`, `CLI-063-run-1/waitAnimation.command.json`, `CLI-063-run-1/extended-visible.command.json`, `CLI-063-run-1/inputText.command.json`, `CLI-063-run-1/longPressOn.command.json`, `CLI-063-run-1/runFlow-string.command.json`, `CLI-063-run-1/assertNotVisible.command.json`, `CLI-063-run-1/scroll.command.json`.
