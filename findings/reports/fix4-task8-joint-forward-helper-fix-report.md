# Task 8 joint forward helper fix report

Status: **PREPARED FOR SCOPED REVIEW; NOT EXECUTED.** This change edits only the Task 8 execution helper. No product source, test suite, Android device, forward, session, build, or candidate was exercised.

## Review findings addressed

1. **CLI source/build identity.** The helper now requires `--build-manifest`. It pins CLI source `a587581723ec2599e0247c186d27667951959d9e`, requires the manifest's source SHA to match, requires release configuration, clean-before/after attestation, successful build/version records, and the exact binary `--version` argv, resolves the manifest binary path against `--binary`, and hashes the executable against the manifest. It also loads the manifest-referenced source-build identity and cross-checks its before/after source, clean status, build exit, binary path, and binary hash. At execution time it independently records and asserts the clean checkout HEAD/status and invokes the binary's `--version`, requiring the output to equal the manifest's captured version. `candidate.json` retains the complete manifest, source-build identity, and independently observed checkout, hash, and version values. The qualification remains joint source validation, not a packaged candidate claim.

   Agreed manifest schema: `schemaVersion: 1`; `sourceSHA`; absolute `sourceCheckout`; `configuration: "release"`; `binary.path` and `binary.sha256`; successful `build.argv`/`build.exit`; and `version.argv`/`version.exit`/`version.stdout`. The controller provided this at `findings/evidence/fix4-84/release-build/build-manifest.json` for the clean `a5875817…` release build.

2. **Runner native identity.** Before any device action, the helper invokes the exact overridden runner with `--version`, records raw stdout/stderr and command metadata, and requires its first native version line to equal `grantiva-runner 1.1.28-grantiva.14-l83-check`. The complete multiline output is retained in `candidate.json`, without inferring an identity from the `l83-check` shorthand. It also retains the full `findings/evidence/fix4-84/joint-source-preparation/identity.json` object alongside the existing source SHA and pinned executable SHA-256. The `.14+android-drivers-2` lookup path remains unchanged and explicitly test-only.

3. **Absent-app and healthy-stock ownership cleanup.** Both cases now run through a case-scoped ownership wrapper. It records before/after project-session state, complete `/tmp/grantiva-sessions` file inventories with hashes and device matching, and full `ps` captures filtered to the exact runner executable plus exact owned serial. While each command runs it records every observed exact runner PID; healthy stock also records its direct runner PID. After return it requires no project session, no device-matching global session, no new global session, no exact device-bound runner process, and no PID-prefixed global-session file for every observed/direct PID. PID checks are read-only and exact; no process is killed by this verification path. Existing serial-scoped forward checks still run immediately and after one second.

4. **Literal Android SIGINT notice.** The interrupt case now requires stderr to contain the exact platform notice proven by `findings/evidence/fix4-84/startup-trace/cli.stderr`, including its leading/trailing newline: `[grantiva] received SIGINT — releasing emulator and reaping child processes`. Exit 130 and all prior forward/session/PID assertions remain.

## Preserved behavior and scope

The two unrelated control forwards remain unchanged. The test-only runner override and its pinned SHA remain unchanged. Foreground ready identity, hierarchy, exact owned attachment, normal stop, SIGINT, absent-app, healthy-stock, serial-scoped final cleanup, and packaged-candidate qualification remain. The helper contains no broad kill or remove-all action.

The reviewed original and review report are preserved under `task8-joint-forward-helper-fix-base/`. `task8-joint-forward-helper-fix.diff` is a fix-only diff against that reviewed helper.

## Verification

Python AST parsing passed. No imports or helper code were executed, and no tests or devices were run.
