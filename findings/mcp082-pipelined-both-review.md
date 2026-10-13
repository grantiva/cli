# MCP-082 pipelined requests — both-platform review

**Verdict: pass for iOS and Android.** The two captures satisfy the literal requirement that JSON-RPC remain responsive while Grantiva-owned simctl/adb subprocess paths execute.

## iOS

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt116/run/events.jsonl` records initialization, followed by one 193-byte pipe write containing `mcp082-ios-context` and `mcp082-ios-list` before the client reads either response. `tools/list` returns at monotonic 475279.5778 and context returns at 475279.7546; all three unique IDs are preserved in `responses.json`. The descendant poll directly observes PID 11655 running `simctl list devices --json` and PID 11669 running `xcodebuild`. The context response is valid and identifies the configured live simulator. Thus the second JSON-RPC request was already queued while the context subprocess path was active and was answered rather than consumed by that child.

The parent wrapper's nonzero status is a post-run harness assertion error: MCP mode did not emit debug command lines to stderr. It does not affect the raw pipeline, child poll, or responses.

## Android

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/MCP082-pipelined-rerun1/run/events.jsonl` records initialization, then one 201-byte pipe write containing `mcp082-android-context` and `mcp082-android-list` before either response is read. Both unique IDs return valid results, with `tools/list` returning before context. `commands.json` pins the QA binary hash `3f3293aa…754a73f8`, Android project, runner home and session ID.

The 2-ms poll did not catch Android's short-lived adb child, but this is not a missing behavioral leg. At exact candidate `8f2cff67`, `ContextTool.context` calls `emulatorSection`; without an active session that function awaits `emulators.listDevices()` and, for each emulator, `avdName(serial)`. The captured context result reports the configured Android emulator by name and serial, which can only be produced through that live dependency path. `Shell.swift` assigns `FileHandle.nullDevice` to these children, and `ShellQuotingTests.testSubprocessesDoNotInheritStandardInput` semantically asserts the same property with a child that reads stdin. The queued `tools/list` response proves the request remained available to the MCP transport.

## Evidence limit

This supports MCP-082 only. It does not claim that the two tool handlers execute serially or concurrently; the contract is that subprocesses never consume MCP stdin and every queued request receives its response. The one-write event, platform subprocess evidence, exact source/test join, and complete response-ID set prove that contract.
