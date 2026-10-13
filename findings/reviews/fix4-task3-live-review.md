# Task 3 independent live evidence review

## Final verdict

**PASS — runner-owned evidence, corrected joint CLI acceptance, provenance, and cleanup are complete.**

The accepted runner captures are `optional-{text,json}-{1,2,3}-final`, not the initial `optional-text-1`. Across all six accepted optional runs, the process exits 0; `report.json` records the flow as passed with command counts `passed:2, warned:1, failed:0`; `flows/flow-000.json` records the missing tap as `warned` with literal error type `element_not_found` and a useful message, then records the following required assertion as `passed`; the ready file records passed flow/overall status; and JUnit records zero failures and retains the warning detail in `system-out`.

The required text and JSON controls both exit 1. Their report and ready surfaces are failed, the missing tap is `failed` with literal `element_not_found` detail, the following assertion is explicitly `skipped`, and JUnit records one failure. This establishes the required/optional behavioral distinction and later-step execution control.

The earlier `*-final` captures remain useful runner-only evidence but do not constitute the final joint acceptance because their older CLI omitted the warned command. The corrected acceptance authority is `live/joint-final/`.

## Corrected joint acceptance

The corrected replay uses CLI source `c1373f6c07bf97ec5cb7978d45c954902958c04a` and binary SHA-256 `c87ae8a4c30d75daf6b7b724e1526b2d1a8f954da422fb18e5343e18358b9f73`, together with runner source `567fd5f3b911cbb6a49cc7864aac3e64830784c7` and binary SHA-256 `001b34982362260f615c979fd65430db8ae53fc1815a39f736f2055137676610`. Each run has an exact `command.txt` recording API-key removal, scoped home, session, CLI binary, serial, source flow, report path, and native CLI `--ready-file` path.

All three text and three JSON optional runs exit 0. On every run:

- CLI text or JSON visibly includes all three steps: passed launch, warned missing tap with useful `element_not_found` message, and the following passed assertion.
- Runner `report.json` records passed flow/overall status and command counts `passed:2, warned:1, failed:0`.
- Flow detail records the tap as `warned` with literal error type `element_not_found` and the following assertion as `passed`.
- Ready status is passed and JUnit has `failures="0"`.

Both corrected required controls exit 1. CLI reports failure and the useful missing-element detail; runner report/flow detail records failed flow and tap plus an explicitly skipped following assertion; ready status is failed; and JUnit has one failure. CLI result JSON omits the skipped command from its display step list, but the binding skipped-later-work assertion is present in runner flow detail and command summary, which are the authoritative execution surfaces.

The replay provenance identifies owned AVD `fix4-3-android`, serial `emulator-5580`, emulator PID `88465`, controlled load PID `2958`, the scoped runner home, and retained APK source `1552ae983a27528eff4c1f8145aa075698b47f71`. The retained APK remains present and recomputes to documented SHA-256 `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a` for Task 8.

## Harness and provenance findings

- `live/invocations.txt` records the common environment with `GRANTIVA_API_KEY` unset, session `fix4-3`, the scoped cloned runner home, the six optional commands, both required controls, and the runner command emitted by the CLI. The CLI's `--ready-file` argument is a real native CLI option consumed by the wrapper; the recorded emitted runner command correctly does not invent or forward a runner ready-file flag.
- `live/ownership.txt`, `emulator-process-final.txt`, and `adb-devices-final.txt` agree on owned AVD `fix4-3-android`, serial `emulator-5580`, final emulator PID `88465`, and the scoped home. The earlier wrapper PID `88267` is not represented as the final emulator process and does not conflict with this evidence.
- `installed-task-runner-path.txt` identifies the versioned installed runner actually selected by the CLI. `installed-task-runner-sha256-final.txt` and `runner-binary-sha256.txt` agree on SHA-256 `001b34982362260f615c979fd65430db8ae53fc1815a39f736f2055137676610`; `runner-source-head.txt` records source `567fd5f3b911cbb6a49cc7864aac3e64830784c7`.
- Every accepted report records its source path as the appropriate retained `findings/evidence/fix4-3/inputs/{optional,required}-miss.yaml`. The APK evidence records fresh source `1552ae983a27528eff4c1f8145aa075698b47f71`, and the retained APK recomputes to the documented SHA-256 `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`.
- The stale initial `optional-text-1` exits 1 and identifies runner version `1.1.28-grantiva.13`; it is correctly excluded. The accepted `*-final` text captures identify the task runner as `1.1.0`, and the installed-path/hash evidence binds the accepted batch to the corrected versioned installation.
- Direct flag captures under `live/device-argv/` record exact shell-escaped environment and argv. Empty and whitespace-only `--device` and its existing `--udid` alias each exit 64 with `invalid argument: --device must not be empty`; `--serial x` exits 1 with `flag provided but not defined: -serial`. These results occur with the reviewed runner at the documented versioned path, before device discovery/signing, and establish the alias ruling without adding `--serial`.

## Cleanup review

Cleanup evidence shows emulator PID `88465` and load PID `2958` absent, no attached ADB devices, no forwards or task sessions, and owned AVD `fix4-3-android` deleted while owner AVD `Pixel_8_API_35` remains. The scoped runner home, demo worktree, and earlier temporary CLI worktree are absent. The residual PID `5266` listed by the broad task-process matcher is an unrelated concurrent `fix4-3-cli` Swift test shell in the CLI review worktree; it is neither an emulator/load process nor a Task 3 owned cleanup target. Protected owner devices were not touched.

No Task 3 acceptance gate remains. Task 8 still must perform its separately required repetition against the final repacked candidate.

No devices or tests were invoked during this review, and raw evidence was not modified.
