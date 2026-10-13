# Candidate 4 smoke replay recipe

This is a rebinding map, not reusable evidence. Do not copy candidate3 results or execute its retained snapshots in place. Root owns the candidate4 build, identity freeze, devices, live execution, and cleanup.

## Final successful references

| phase | successful candidate3 reference | executable logic / invocation source |
|---|---|---|
| candidate identity and upgrade | `round4-smoke-candidate3/01-candidate/executed-controller.py`; `01-candidate/upgrade/acceptance.json` | Controller script is the exact executed logic, but is heavily candidate3-specific. Reviewed identity primitives are `findings/tools/round4-smoke/candidate_identity.py` and `run_phase.py`. |
| Android runner | `02-runner-android/helper/acceptance.json`; exact argv in `02-runner-android/invocation/start.json` | Executed snapshot `02-runner-android/executed_helper.py`; reviewed source `findings/tools/round4-smoke/android_runner_smoke.py`. |
| lifecycle | **Only** `03-lifecycle-attempt3/helper/acceptance.json` and `03-lifecycle-attempt3/invocation/start.json` | Executed snapshot `03-lifecycle-attempt3/executed-helper.py`; reviewed source `findings/tools/round4-smoke/lifecycle_smoke.py`. Do not use `03-lifecycle/` or `03-lifecycle-attempt2/`. |
| joint forward | `03b-joint-forward/helper/acceptance.json`; exact argv in `03b-joint-forward/invocation/start.json` | Executed snapshot `03b-joint-forward/executed-helper.py`; candidate3 harness path in argv is `.superpowers/sdd/2026-10-13-round4-fix-wave/task8-candidate3-harness/forward_joint_live.py`. |
| iOS MCP | `04-mcp-ios/helper/acceptance.json`; exact argv in `04-mcp-ios/invocation/start.json` | Executed snapshot `04-mcp-ios/executed-helper.py`; reviewed sources `findings/tools/round4-smoke/mcp_smoke.py` and `mcp_client.py`. |
| Android MCP | `05-mcp-android/helper/acceptance.json`; exact argv in `05-mcp-android/invocation/start.json` | Executed snapshot `05-mcp-android/executed-helper.py`; same reviewed MCP sources. |
| docs/output | `06-docs-output/executed-controller.py`; `06-docs-output/acceptance.json` | Controller-only script. It generates 172 help pages, checks public terms and doctor text/JSON, runs the bounded corpus tests, then promotes the corpus. |
| force teardown | **Only** `07-final-force-teardown-attempt2/helper/acceptance.json` and its `invocation/start.json` | Successful argv uses candidate3 `foreground_force.py` with `--phase force-teardown --allow-force-reclaim-owned-ios`. Do not use `07-final-force-teardown/`. |
| final cleanup | `08-final-cleanup/acceptance.json` plus its `commands/*.json` records | No general replay helper qualifies. Reconstruct controller-owned targeted cleanup from these command records after rebinding and fresh ownership checks; never use global teardown. |

All paths above are relative to `findings/evidence/round4-smoke-candidate3/`. The reviewed helper contract and phase ordering are in `findings/tools/round4-smoke/README.md` and `lifecycle-README.md`.

## Candidate4 bindings to replace

Create a new candidate4 evidence root and fresh manifests. Rebind every occurrence of:

- candidate manifest and ownership manifest: new `candidate.json` and `provision/ownership.json`, with fresh hashes and verified source HEADs;
- CLI source checkout/SHA, QA binary, bundle, bundle-file manifest, packaged runner, installed runner, install stamp, and runner source SHA;
- scratch root `/private/tmp/grantiva-round4-candidate3-9lkulx9q`, including packaged-native, runner-home, project, no-session, cycle, and ready-forward directories;
- both `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME`; use one fresh APFS clone and record its before/after inventory;
- `GRANTIVA_SESSION_ID=fix4-8-c3` / `--session-id fix4-8-c3` to a unique candidate4 session; keep `GRANTIVA_API_KEY` unset;
- iOS UDID `33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E`, Android serial `emulator-5580`, and AVD `smoke4-c3-android` to newly provisioned candidate4-owned identities;
- iOS app, Android APK, demo checkout/SHA, and artifact hashes to candidate4-qualified build artifacts;
- every `--output`/`--evidence` path and transient input directory to the new evidence root;
- candidate3 harness paths under `.superpowers/.../task8-candidate3-harness/` to reviewed candidate4 copies whose hashes are recorded before execution.

Keep stable only after fresh validation: protected owner IDs, application IDs, required repetition counts (`--pairs 10`, crash/favorite counts), platform-specific tool paths, and literal semantic fixtures. Rehash copied seeds and fixture directories in the new evidence root.

## Phase-specific rebinding

- **Identity:** rewrite the controller constants and assertions for candidate4. Candidate3 hardcodes its evidence root, runner SHA/version/stamp, demo SHA/path, old-candidate backup, WDA manifest, QA destination, build scratch, session, and candidate2 predecessor. Do not run it unchanged. Freeze the new manifest before executable smoke phases.
- **Android runner:** preserve every flag from `02-runner-android/invocation/start.json`; rebind source, binary/bundle/runner/home, project, serial/AVD, APK, cycle project, inputs, analyzers, and evidence. The `runner-inputs` and `optional-inputs` directories are deeper than the shallow inventory and must be copied/rehashed explicitly.
- **Lifecycle:** start from the attempt3 argv only. Rebind manifests, source/artifacts, both devices, project/home/session, app, and output. Run validate-only first per `lifecycle-README.md`.
- **Joint forward:** rebind candidate/ownership, packaged runner/home, ready-forward project, binary/bundle/source, and output. Fresh ports, PIDs, sessions, forwards, and control processes must be discovered and ownership-proved; never carry candidate3 numeric ports or PIDs from helper evidence.
- **MCP:** preserve platform and `--pairs 10`; rebind device, project/no-session project, hierarchy seed, artifacts/home, manifests, and evidence. iOS keeps simctl/app-ID bindings after fresh app verification; Android keeps the fresh AVD binding.
- **Docs/output:** change the hardcoded candidate3 root, scratch, session, and output. Generate a new 172-page corpus from candidate4. The script runs Swift corpus tests, so root must treat that as an explicit candidate4 test/build operation rather than a read-only replay.
- **Force teardown:** use attempt2/`foreground_force.py`, not the failed first attempt. Rebind all identities and output; retain the destructive-phase flag only for the freshly owned iOS target after live ownership proof.
- **Cleanup:** prove exact current iOS UDID, Android AVD/serial/PID, sessions, leases, locks, forwards, and protected inventory immediately before action. Shut down/delete only candidate4-owned targets, signal only the authenticated owned PID, and prove absence afterward. Candidate3 physical-deletion results are not assumptions for candidate4.

## Do not replay

- `03-lifecycle/` and `03-lifecycle-attempt2/`: failed attempts and cleanup context only.
- `07-final-force-teardown/`: failed first force-teardown attempt; use attempt2 logic as the reference.
- Any candidate3 `executed-helper.py` or controller script without first copying, reviewing, rebinding, and hashing it into candidate4 evidence.
- Candidate3 raw reports, acceptance files, ports, PIDs, sessions, device identities, runner home, scratch projects, or cleanup conclusions as candidate4 evidence.
- `__pycache__` files or old fix4 live harnesses referenced by history. The reviewed source helpers in `findings/tools/round4-smoke/` are the preparation baseline.

For every phase, capture a fresh top-level start/result pair with exact argv, cwd, environment, timestamps, exit, raw streams, helper hash, candidate/ownership hashes, and acceptance path. A failure remains a candidate4 failure; do not fall through to later live phases.
