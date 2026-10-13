# Android B2-K106 / B3-L35 rerun4 review

Verdict: both rows pass.

The three row-owned secondary runs use the exact `01-browse.yaml` input. Their command records distinguish keep-alive, ordinary ephemeral-report, and ordinary preserved-report forms. Each CLI parent is killed with SIGKILL only after its exact lease claim lists the expected temporary directories. All three parents return `-9`.

The text teardown names both keep-alive temporary paths. Both JSON teardowns return `temporaryDirectoriesRemoved`; the ordinary run lists its two ephemeral paths and the preserved-report run lists only its one staging path. Every listed path and each serial lease are absent afterward. `posthoc-temp-paths.tsv` and the empty `posthoc-comm-common.txt` retain the literal before/after set comparison. All teardown exits are zero.

The explicit report directory and sentinel survive. During all three secondary teardowns, the unrelated primary run remains alive and both of its claimed directories remain present; `decoded.json` records those paths before the primary's later clean stop. Its final exit is zero. The row-owned AVD is deleted and absent from the final AVD inventory.

Exact-head source/tests complete the semantic clauses: `EmulatorManagerTests.swift:1110-1140` and `SimulatorReaperTests.swift:395-435` assert dead-owner removal/listing, live-owner preservation, and explicit report preservation; `SimulatorLeaseTests.swift:278-285` covers the claim-field round trip. The prohibited `--all --force` runtime half was not executed; the exact EmulatorManager tests cover that shared branch as permitted by the Global Constraint.

The lease claim's transient `keepAlive: false` field does not change the prescribed input: `legs/keepalive/command.json` contains `--keep-alive`, the process remains alive until the harness SIGKILL, and its two ephemeral paths are reclaimed. The row criteria concern command form, liveness, and cleanup rather than that construction-time claim field.
