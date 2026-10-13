# Stable manual emulator fixture — fix round 1 review package

Review input: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/.superpowers/sdd/2026-10-13-round4-fix-wave/task9-android-stable-manual-fixture-review.md`.

Review targets:

- `stable-manual-emulator.py` — SHA-256 `bd919f9a8d5250ebe394bf9d1c8563842e288fc28ed36e5f62524f9481b5f1c6`
- `test-stable-manual-emulator.py` — SHA-256 `561b941efc58aad69d5a6a818acaf802192f3d67a85b4d07a317603342ef78e1`
- `stable-manual-emulator-fake-tests-rerun1.txt` — SHA-256 `4f8737a9f17b4e4b7c5ba769f32694354a69793ec0aa8ee7eb49e43dc4c040fd`

Acceptance mapping:

1. Stable identity excludes PPID from equality while retaining launch/current PPID in evidence. Expected AVD and port tokens are checked in the current process command.
2. Exact launch argv binds port 5556. Preflight rejects an attached `emulator-5556` or occupied TCP 5556 before spawn.
3. Every external probe uses the remaining deadline. Timeout records include argv and partial streams; verify honors its supplied timeout.
4. Pending launch and returned PID journals precede optional identity work. Launch terminal records are exclusive; verification terminal records are monotonically numbered and immutable.

The inert fake checks cover healthy PPID reparenting, a hung subprocess probe, immediate child exit after PID journaling, and two verification calls without overwriting the first artifact. No live emulator/device/network operation occurred.
