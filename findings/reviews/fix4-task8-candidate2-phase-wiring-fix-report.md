# Task 8 candidate 2 phase wiring correction

## Scope and change

Corrected only the MCP branch wiring in `candidate2_phase.py`. No phase, helper, validator, device command, runner start, or cleanup was executed.

Before either MCP branch invokes the frozen CLI's detached `runner start`, the dispatcher now records and requires a `preflight` invocation of the existing copied `candidate_identity.py`. The preflight reuses the shared frozen candidate, ownership, source root, binary, bundle, packaged runner, and runner-home arguments. It also passes the selected platform and device, plus the owned Android AVD for the Android branch.

The existing `mcp_smoke.py` invocation retains the same identity arguments and its own validation as defense in depth. All accepted helper selection, phase separation, MCP start arguments, scoped stop behavior, session identity checks, environment bindings, helper evidence copy, and non-MCP wiring remain unchanged.

## Verification

- The corrected source compiled in memory and parsed as Python.
- Static checks confirmed the preflight invokes the copied `candidate_identity.py` with shared identity flags and selected platform/device.
- Static checks confirmed the Android branch adds `--android-avd`.
- A call-order check established `preflight` precedes `start`, which precedes the retained MCP helper `invocation`.
- Static checks confirmed the MCP helper still receives the shared identity arguments.

The pre-correction script is preserved in `task8-candidate2-phase-wiring-fix-base/candidate2_phase.py`; the complete scoped diff is `task8-candidate2-phase-wiring-fix.diff`.
