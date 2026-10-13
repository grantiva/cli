# MCP-078 Android killed-app triage

Round-3 live evidence at candidate CLI `8f2cff67`, runner `.13`, and owned `cov3-android` shows a mixed result after `adb -s emulator-5554 shell am force-stop com.kylebrowning.landmarks` returned 0 and `pidof` returned 1:

- `grantiva_tap`, `grantiva_type`, and `grantiva_script` returned tool-level `isError` results.
- `grantiva_screenshot`, `grantiva_swipe`, `grantiva_a11y_tree`, and `grantiva_a11y_check` returned success against system UI.
- No response used a JSON-RPC error, and the server remained alive.

Evidence: `findings/evidence/cov3-android/MCP-killed-app-errors/` preserves the exact requests, raw responses, force-stop/pid checks, held session report, and cleanup.

This fails the matrix's explicit MCP-078 requirement that every session tool return `isError` against a session whose app was killed. The shipped docs describe these as device/session tools and do not explicitly promise app-process validation after a force-stop. Candidate `Sources/GrantivaMCP/ToolRegistry.swift` dispatches the seven session tools, while the focused source search found no app-process-alive guard in that dispatch/UI-tool path. Controller triage should therefore decide whether the matrix binds a missing product invariant or needs a contract clarification; the Android verdict remains fail against the current matrix either way.
