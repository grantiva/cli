# Task 8 lifecycle smoke

`lifecycle_smoke.py` is the executable Task 8 phase-03 helper. It consumes the controller-created `grantiva.task8.candidate.v1` and `grantiva.task8.ownership.v1` manifests through the shared `candidate_identity.validate` function before its first device query. The validator binds the merged repository, candidate executable/hash/version, exact resource-bundle file manifest, runner source and packaged/installed identities, install stamp, clean-built iOS app manifest, literal `fix4-8` session, and controller-created device records.

Required arguments are:

```text
--candidate-manifest --ownership-manifest --binary --bundle --runner --source
--project --runner-home --session-id fix4-8 --ios-udid --ios-app
--android-serial --android-avd --output
```

`--adb`, `--ios-bundle-id`, and `--android-application-id` are optional overrides. All filesystem bindings and the new evidence directory must be absolute.

Before running lifecycle commands, the helper also proves that the owned iOS UDID resolves to the manifest's simulator name and runtime, and that the Android serial resolves live to the manifest's AVD name and SDK runtime. It rejects the protected owner devices.

Run configuration-only validation by adding `--validate-only`. That mode parses and validates absolute input paths and destructive-phase isolation without querying devices, executing candidate artifacts, or claiming acceptance. Actual execution without `--phase` runs the five non-destructive Task 8 phases:

- plain startup interruption and ready-state interruption on both platforms;
- genuine `starting` null-port to same-PID `ready`, immediate Landmarks hierarchy, and exact stop on both platforms;
- canonical absent-install refusal and exact frozen iOS app restoration, plus prompt Android missing-app failure;
- successful, failed, and interrupted iOS log runs with exact marked-child absence, report state, and one truthful verbose terminal diagnostic per run;
- the three retained circular-flow paths and exact diagnostics.

The helper intentionally does not claim the wider Task 9 lifecycle family. Quiet/JSON startup repetitions, genuine WDA timeout, unprompted runner/WDA death, absent-install no-launch variants, free-force, non-force refusal, and other live-run reaping controls remain mandatory Task 9 work.

Run force teardown alone, last, with a new evidence path:

```text
--phase force-teardown --allow-destroy-owned-ios
```

It starts an actual detached session, checks the live hierarchy, requires JSON `runnerSessionStopped: true`, `reclaimed: true`, typed process arrays, and absence of the exact runner PID plus project/shared session state. It writes `IOS-DEVICE-RECREATE-REQUIRED.json` immediately after the destructive command returns; the controller must provision and record a new owned simulator before any later iOS command.

Every nested command preserves argv, cwd, start, exit, stdout, and stderr. `owned-resources.json` records verified provenance and exact observed PIDs. If an assertion fails after a runner starts, bounded cleanup stops only a session whose PID was previously verified against the owned device, signals only that exact verified PID if needed, removes only forwards enumerated for the owned Android serial, and records all actions in `cleanup.json`. `acceptance.json` is written only after all selected assertions pass.
