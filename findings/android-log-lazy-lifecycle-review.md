# Android logging, lazy session, and emulator lifecycle review

## B-A08

`B-A08-log-levels-rerun1/assertions.json` is consistent with the retained commands and stderr. Implicit/default/info each launch one timestamp-bounded `adb logcat ... -T ... -s '*:I'`; debug uses `*:D`; no invocation clears logcat; and invalid `warning` exits 64 while naming valid values. The source package pins the exact-head AndroidPlatform argument construction and RunCommand validation semantics. This fully supports B-A08.1, B-A08.3, and the source-check row B-A08.4.

## B-C11.2

`B-C11.2-no-session-lazy-rerun1` covers all seven named session-dependent families before a session: tap, swipe, type, screenshot, tree, check, and script each returns `isError: true`, contains `No active runner session`, and gives the start remedy. The same still-running MCP server then observes the detached session and succeeds on the first tree request; `lazy-attach-summary.json` records success after ten bounded attempts. This proves both error transport and re-check/lazy attachment, supporting B-C11.2 `[android]`.

## MCP-059 through MCP-062 and D2-35

`MCP059-062-D235-emulator-lifecycle-rerun1` supplies the exact configured and empty-directory variants. Name-only ensure creates owned AVDs and delete removes them in both environments. Separately hand-made AVDs are refused without force and deleted with force in both environments. The running-primary leg refuses deletion with the documented serial-bearing remedy, the missing boot leg errors, the primary survives, `adb-before.txt`/`adb-after.txt` are unchanged, and every row-created name is absent afterward. The 13 frozen assertions all pass. This supports MCP-059, MCP-060, MCP-061, MCP-062, and D2-35 `[android]`; the evidence distinguishes created, hand-made, running, and missing cases rather than inferring them from cleanup alone.
