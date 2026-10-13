# MCP-082 subprocess stdin audit

The row is **partial**, with one small runtime complement.

At candidate `8f2cff67`, `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Shell.swift:5-22` explains the MCP failure mode and assigns `FileHandle.nullDevice` to every shell child's standard input. The other direct process launchers likewise use a null input (`RunnerManager.swift:515`, `WDADeviceHome.swift:42`, `DefaultSimulator.swift:70`, and the resolved-tool shell overloads at `Shell.swift:74-109`). `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/ShellQuotingTests.swift:11-32` is a semantic assertion: a child `cat` must see EOF and complete within five seconds, and `cat; echo done` must return `done`.

The retained live MCP transcripts prove that requests before and after build, ensure, and adb/simctl-backed tools all receive their IDs and responses. They do not by themselves prove the literal matrix timing, “JSON-RPC while `adb shell`/`simctl` subprocesses run,” because the ordinary client sends and awaits one request at a time. A completed subprocess followed by another successful request cannot detect whether the child could have consumed a request queued during its lifetime.

The smallest complement is one pipelined MCP transport capture per platform: start a tool whose owned adb/simctl subprocess remains active long enough to observe, write a second JSON-RPC request with a unique ID before the first tool returns, and retain the raw interleaved responses plus the verbose child-command interval. Both IDs must be answered and neither request may disappear into the child. No extra broad MCP corpus is needed.
