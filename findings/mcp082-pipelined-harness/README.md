# MCP-082 parent-executed harness

Run once from each platform's existing owned project, with a new evidence directory:

```sh
findings/mcp082-pipelined-harness/run-parent.sh ios /absolute/owned/ios/project /absolute/new/evidence/MCP082-ios-pipelined-rerun1
findings/mcp082-pipelined-harness/run-parent.sh android /absolute/owned/android/project /absolute/new/evidence/MCP082-android-pipelined-rerun1
```

The client waits only for initialization. It then writes `grantiva_context` and a unique-ID `tools/list` request in the same pipe write and flush, before reading either response. Context is read-only and necessarily invokes `xcrun simctl list devices` plus `xcodebuild -version` on iOS, or `adb devices` (and normally `adb -s … emu avd name`) on Android. The second request is therefore queued on MCP stdin while that platform child path executes. No arbitrary sleep, build, install, boot, teardown, or UI action is used.

The result is valid when `responses.json` contains all three unique IDs, `events.jsonl` records one `pipelined-context-then-list` write preceding both responses, and `subprocess-debug-lines.txt` names the platform child. A 2-ms process-tree sampler captures children even though `mcp` has no verbosity flag; any debug command lines emitted by the binary are retained too. The preserved exact-head source/test excerpts establish that these children receive `/dev/null` rather than MCP stdin.


## Executed evidence

The generic `run-parent.sh` draft was not executed and is not a verified entry point. The reviewed runs use the frozen client in iOS `findings/evidence/cov3-ios-attempt116/input/` and Android `findings/evidence/cov3-android/MCP082-pipelined-rerun1/input/`. Their harness/commands metadata records the exact invocation and QA environment. See `findings/mcp082-pipelined-both-review.md` for the evidence verdict and the distinction between observed subprocess polling and exact-source corroboration. The client creates its own output directory; callers must not precreate that directory.
