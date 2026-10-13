# Task 8 direct runner runtime environment correction

Status: harness correction and no-device validation complete; independent scoped review and controller rerun remain pending. No product failure or smoke acceptance result is claimed. No device commands were executed.

## Preserved originals and scope

Before edits, copied the durable and scratch Android helpers to `task8-runtime-env-base/durable-android_runner_smoke.py` and `task8-runtime-env-base/scratch-android_runner_smoke.py`. Only `findings/tools/round4-smoke/android_runner_smoke.py` and its byte-identical `task-8-harness/android_runner_smoke.py` mirror changed. Prior raw attempts, including attempt3, remain untouched. No product source changed.

## Defect and correction

Attempt3 healthy stderr reported missing `runner-home/drivers/android`: direct execution used the clone root for `MAESTRO_RUNNER_HOME`, although drivers are under the installed version directory. The helper now performs existing full candidate validation, reads candidate bytes bound to the returned manifest hash, derives the exact installed binary parent, verifies that parent equals clone-root/versions/installStamp, verifies installed and supplied packaged runner bytes share the validated SHA256, and requires `drivers/android` to exist there.

`MAESTRO_RUNNER_HOME` is now `/private/tmp/grantiva-round4-smoke-j35_m7hg/runner-home/versions/1.1.28-grantiva.14+android-drivers-2`. `GRANTIVA_RUNNER_HOME` remains `/private/tmp/grantiva-round4-smoke-j35_m7hg/runner-home` for CLI upgrade/cache resolution. The common child PATH now starts with the resolved explicit `--adb` parent, so direct runner subprocesses can resolve ADB. Provenance additionally records `maestroRunnerHome` and `adbParent`. Argument interface and acceptance logic are unchanged.

Production consistency was inspected in release-round4: `RunnerManager.swift:297` returns `currentInstallDir` as runnerDir; `RunnerSession.swift:99,218,404,567,690` passes it through platform runnerEnvironment; `Android/AndroidPlatform.swift:265-270` sets MAESTRO_RUNNER_HOME to that directory and prepends Android SDK tools to PATH. The harness now follows that directory/PATH behavior.

## Checks

- AST parsing and `android_runner_smoke.py --help` passed; scratch mirror is byte-identical; `git diff --check` passed.
- Executed only the helper initialization prefix ending before `def run`, using attempt3 arguments with a fresh SDD check output directory. This performs real frozen candidate/ownership validation and binary `--version` checks, but cannot reach any device command or acceptance flow.
- Verified exact installed parent, retained clone root, existing Android driver directory, and PATH resolution to `/Users/kyle/Library/Android/sdk/platform-tools/adb` without launching ADB.
- Bound candidate manifest SHA256: `7c6b9634572c982e724849548510805a99168217228e7eb1ab689fdd04d8bc73`.
- Installed and packaged runner SHA256: `eb289d8a505b22351b88bf2dfb728dd4af74fb7187ce68637d99c809bf55cb07`.
- Retained focused check outputs: `task8-runtime-env-check/result.json` and `task8-runtime-env-check/provenance.json`.

Controller should obtain independent scoped review before rerunning into a new evidence directory; existing attempts must remain preserved.
