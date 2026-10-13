# Candidate4 bounded lifecycle recorder correction

Status: IMPLEMENTED; seven deterministic tests PASS; scoped review pending. No lifecycle, device, build, product, or other live operation was executed. Original `03-lifecycle` failures and raw evidence remain untouched. This is not a lifecycle acceptance result.

## Changes

- Preserved the original helper adjacent as `findings/evidence/completion-candidate4/harness/lifecycle_smoke.before-recorder-fix.py`, SHA-256 `7154062b9884112d5b62d112e8a778794a68b1ec8a13d503f74bb90de594b7b5`. Also preserved `foreground_force.before-recorder-fix.py` before changing its base binding.
- `copy_report_snapshot` now copies into an adjacent temporary staging directory. Source-root/subtree ENOENT discards the staged partial copy. Direct OSError filenames and flattened shutil.Error filenames must belong to the authenticated source; tuple source membership alone cannot suppress a destination failure. Mixed errors and permission/I/O/destination failures propagate.
- A complete retained report is never overwritten by later copies, including successful copies containing incomplete bytes. Staging creation, destination replacement, and cleanup errors remain outside the accepted source-error handling.
- The worker records source-disappearance observation, joins normally, and records terminal source absence if its final copy sees that race. Mandatory retained-byte validation still runs after joining. No readiness, hierarchy, normal-stop, PID, or session-cleanup acceptance assertions were removed.
- Required retained validation checks passed/endTime report and flow summaries, referenced flow JSON existence and completion, matching flow ID, completed passed commands, and command counts. Missing, malformed, or incomplete proof fails. Startup-interrupt's existing report-optional behavior is unchanged.
- `foreground_force.py` only changes `APPROVED_BASE_SHA` to the corrected helper hash.

Exact unified diff: `findings/evidence/completion-candidate4/harness/recorder-fix.diff`, SHA-256 `cfb38acecb024b709f8f9f7067083ca56ae3cf2bddd6dad2eef9fc64e5a95e98`.

## Hashes

| File under findings/evidence/completion-candidate4/harness | SHA-256 |
| --- | --- |
| lifecycle_smoke.py | `29b89b63681932baba6601051cdffc7b501fb03c6433c91878506c4eca9bb7be` |
| foreground_force.py | `03728f386e6a6433b7efdc9558cae3a4ef35ade2f5439936a60a2acbcad0cc3c` |
| test_lifecycle_recorder.py | `993676272f4ed97abca3153170076595116aef6e772a00c5c53b8fafcd0449ea` |
| argv-lifecycle-recorder-fix1.json | `e124db134082969ce1e6e30a2567c08b5bf5c1d6e90c6281ff0ffc722d30891e` |

## Verification

Ran `python3 findings/evidence/completion-candidate4/harness/test_lifecycle_recorder.py`: seven tests PASS (0.044 seconds). Exact output retained in `findings/evidence/completion-candidate4/harness/recorder-fix-tests.txt`. The earlier six-test run also passed; the final run adds explicit required-stop failure when source disappearance leaves no retained report.

Coverage:

1. Root and nested source disappearance, direct and wrapped ENOENT, after partial staged writes; byte-for-byte complete snapshot preservation, also for later successful incomplete copies.
2. Direct/wrapped permission, destination ENOENT, I/O, and mixed-error propagation with unchanged retained bytes.
3. Destination promotion failure propagation.
4. Worker terminal join/metadata and successful retained validation, including repeated stop.
5. Worker with incomplete retained flow refuses acceptance.
6. Source race with no retained report refuses required stop.
7. Missing flow JSON, malformed report, incomplete report and invalid summary refuse validation.

The tests use temporary local fixture files and fake copy errors; the worker uses an in-memory fake runner binding and synthetic session. No subprocess/device operation is called. Python compilation of both modified helpers also passed.

## Prepared adjacent resume (not executed)

`findings/evidence/completion-candidate4/harness/argv-lifecycle-recorder-fix1.json` contains the complete explicit argv and existing bound environment/cwd. It selects `detach-ready`, `absent-app`, `log-cleanup`, and `cycle-controls`, the remaining originally default-selected phases. It excludes completed `startup-interrupt`; `force-teardown` was not part of that original default selection and remains its separate invocation. `detach-ready` includes both platforms and their ready-state interrupt controls.

Output is the absent adjacent path `findings/evidence/completion-candidate4/03-lifecycle-recorder-fix1/helper`. Original `argv-bound.json` is unchanged. Root may add this argv under a new `lifecycle-resume` key after scoped review. All original live failures remain preserved, and lifecycle acceptance remains pending.
