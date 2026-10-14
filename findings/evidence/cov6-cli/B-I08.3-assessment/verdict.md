# B-I08.3 candidate5 clause assessment

Verdict: **PASS**.

Expected: GrantivaCoreTests/SimulatorCapacityTests: `prune` drops an active `simulator:<udid>` record with a dead pid; a SimulatorManager test with a fake shell asserts no `simctl shutdown` for a device that was already booted. (brief I08)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-I08.3-run-1/source-inspection.command.json`.
