# Task 8 candidate 2 phase wiring review

**Verdict: APPROVED.** Helper paths, argument names, phase separation, frozen-identity preflight, and scoped MCP stop behavior are correctly wired. The focused correction introduces no new scoped defect.

## Focused correction re-review

**Prior P1 — ADDRESSED.** Both MCP branches now run the copied reviewed `candidate_identity.py` through the dispatcher's recorded `preflight` step before `runner start`. The preflight receives the complete shared frozen identity arguments plus selected platform/device, and Android additionally receives its owned AVD. A nonzero validation result stops execution before the live start. The MCP helper retains its own validation after start as defense in depth. The reported syntax and static call-order proof establishes `preflight < start < invocation`; no execution was needed for this wiring correction.

## Verified wiring

- The dispatcher exposes exactly one selected phase from Android, lifecycle, joint-forward, iOS MCP, Android MCP, and force teardown, and creates a distinct absent output directory for it.
- Shared identity arguments exactly match `android_runner_smoke.py` and `mcp_smoke.py`. Lifecycle correctly translates only `--source-root` to its required `--source`; all other candidate/ownership/binary/bundle/runner/home arguments match. Joint-forward uses its reviewed candidate/ownership/source/binary/bundle/packaged-runner/home/project/output interface.
- Android paths bind the frozen APK, owned serial and AVD, reviewed sampler/analyzer, frozen input sets, cycle project, and expected flow files. All referenced inputs currently exist.
- Lifecycle without `--phase` selects the reviewed five non-force phases. Force teardown is dispatched alone with `--phase force-teardown` and `--allow-force-reclaim-owned-ios`, satisfying the helper's isolation rule. The dispatcher makes no physical-delete claim; manual cleanup and the final gate remain controller work.
- MCP starts only the selected owned platform/device with its expected app identity and project. The reviewed helper receives the matching active/no-session projects, platform seed, ten pairs, and platform-specific arguments.
- MCP cleanup is scoped to the selected project session. Before stop, the dispatcher requires the session's platform and device identity to match the selected target; it then uses the frozen CLI from that project and requires the session file to disappear. The `finally` block covers start/helper failures that leave a session.
- The exact copied helper is saved into phase evidence before each normal invocation. Environment bindings consistently remove the API key and set literal session `fix4-8`, runner homes, Android SDK, Java, and ADB path.

This was a narrow read-only wiring review. No phase, helper, test, device command, or cleanup was run, and helper internals were not re-reviewed.
