# Task 3 independent live evidence review

## Initial verdict

**Runner-owned live evidence: PASS. Full Task 3 joint acceptance: PENDING.**

The accepted runner captures are `optional-{text,json}-{1,2,3}-final`, not the initial `optional-text-1`. Across all six accepted optional runs, the process exits 0; `report.json` records the flow as passed with command counts `passed:2, warned:1, failed:0`; `flows/flow-000.json` records the missing tap as `warned` with literal error type `element_not_found` and a useful message, then records the following required assertion as `passed`; the ready file records passed flow/overall status; and JUnit records zero failures and retains the warning detail in `system-out`.

The required text and JSON controls both exit 1. Their report and ready surfaces are failed, the missing tap is `failed` with literal `element_not_found` detail, the following assertion is explicitly `skipped`, and JUnit records one failure. This establishes the required/optional behavioral distinction and later-step execution control.

The current `*-final` captures do **not** satisfy full joint acceptance. The merged CLI used for them omits the warned optional command from its text and JSON result rendering. For example, the optional JSON output contains only `launchApp` and the later `assertVisible`, while the runner flow detail contains all three commands and marks `tapOn` warned. This is the expected CLI counterpart gap and must be resolved and replayed before Task 3 closes.

## Harness and provenance findings

- `live/invocations.txt` records the common environment with `GRANTIVA_API_KEY` unset, session `fix4-3`, the scoped cloned runner home, the six optional commands, both required controls, and the runner command emitted by the CLI. The CLI's `--ready-file` argument is a real native CLI option consumed by the wrapper; the recorded emitted runner command correctly does not invent or forward a runner ready-file flag.
- `live/ownership.txt`, `emulator-process-final.txt`, and `adb-devices-final.txt` agree on owned AVD `fix4-3-android`, serial `emulator-5580`, final emulator PID `88465`, and the scoped home. The earlier wrapper PID `88267` is not represented as the final emulator process and does not conflict with this evidence.
- `installed-task-runner-path.txt` identifies the versioned installed runner actually selected by the CLI. `installed-task-runner-sha256-final.txt` and `runner-binary-sha256.txt` agree on SHA-256 `001b34982362260f615c979fd65430db8ae53fc1815a39f736f2055137676610`; `runner-source-head.txt` records source `567fd5f3b911cbb6a49cc7864aac3e64830784c7`.
- Every accepted report records its source path as the appropriate retained `findings/evidence/fix4-3/inputs/{optional,required}-miss.yaml`. The APK evidence records fresh source `1552ae983a27528eff4c1f8145aa075698b47f71`, and the retained APK recomputes to the documented SHA-256 `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`.
- The stale initial `optional-text-1` exits 1 and identifies runner version `1.1.28-grantiva.13`; it is correctly excluded. The accepted `*-final` text captures identify the task runner as `1.1.0`, and the installed-path/hash evidence binds the accepted batch to the corrected versioned installation.
- Direct flag captures under `live/device-argv/` record exact shell-escaped environment and argv. Empty and whitespace-only `--device` and its existing `--udid` alias each exit 64 with `invalid argument: --device must not be empty`; `--serial x` exits 1 with `flag provided but not defined: -serial`. These results occur with the reviewed runner at the documented versioned path, before device discovery/signing, and establish the alias ruling without adding `--serial`.

## Remaining gates

1. Correct the CLI warned-status decode/render path, complete its independent review/CI, and replay the joint optional acceptance. Each of three text and three JSON results must visibly include the warned optional tap and its useful `element_not_found` detail, include the following passed assertion, and agree with runner `report.json`, flow detail, ready status, JUnit zero failures, and exit 0.
2. Preserve the required text and JSON controls in the corrected replay: exit 1, failed flow/command, literal `element_not_found`, following command skipped, failed ready status, and JUnit one failure.
3. Retain per-batch CLI source, runner source/path/hash, input source paths, scoped-home/API-unset environment, owned serial, and process evidence so the corrected captures cannot be confused with the stale initial run.
4. Perform the already-deferred cleanup of the owned emulator and temporary cloned home only after the corrected replay is complete, and record cleanup evidence. Protected owner devices must remain untouched.

No devices or tests were invoked during this review, and raw evidence was not modified.
