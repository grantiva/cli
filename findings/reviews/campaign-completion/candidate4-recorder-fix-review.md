# Candidate4 recorder correction — scoped review

Specification and quality verdict: APPROVED for the diagnosed report-disappearance correction and prepared adjacent lifecycle resume. No scoped blocker found. This is not approval of a completed lifecycle run or the smoke gate.

Reviewed the fix report, preserved original, recorder-fix.diff, corrected helper, dependent foreground binding, seven deterministic test cases and retained output, and prepared resume argv. No tests or live commands were rerun; no product/device/build changes were made.

The corrected copy operation stages into an adjacent temporary directory. Authenticated source-root/subtree ENOENT discards only that staged copy, leaving complete retained bytes untouched. Direct errors inspect the filename; wrapped shutil errors inspect both tuple source and parsed ENOENT filename. Destination errors, permission/I/O errors and mixed errors propagate. Replacement/promotion errors remain outside the narrow exception allowance. Existing completed report bytes survive even a later successful but incomplete copy.

The worker can now finish after the observed disappearance, join and record terminal state, while required report validation still executes against retained bytes. Missing or malformed reports, incomplete summary/flow data, missing referenced detail, incomplete commands and inconsistent counts refuse qualification. The validator is compatible with the complete report and flow retained in the original failed attempt. No ready-session, immediate hierarchy, stop, PID or shared-session assertions were removed. The original failure remains distinct evidence.

The retained fixture output records seven passing tests in 0.044 seconds. Inspection confirms meaningful cases for direct/wrapped root and subtree disappearance after partial writes; complete snapshot preservation; unrelated and mixed errors; destination promotion failure; worker join/terminal metadata/repeated stop; incomplete worker evidence; and no retained report. These are recorder-only deterministic checks, not substituted live acceptance.

Verified lifecycle_smoke.py SHA-256 `29b89b63681932baba6601051cdffc7b501fb03c6433c91878506c4eca9bb7be`. foreground_force.py SHA-256 `03728f386e6a6433b7efdc9558cae3a4ef35ade2f5439936a60a2acbcad0cc3c`; its diff only updates APPROVED_BASE_SHA to that lifecycle hash.

The prepared argv writes to new `03-lifecycle-recorder-fix1/helper` and selects detach-ready, absent-app, log-cleanup and cycle-controls. It excludes completed startup-interrupt, retains candidate4/device/home bindings and API-key-unset environment, and does not overwrite `03-lifecycle`. Detach-ready includes both platforms and the ready foreground controls, collecting the evidence omitted when the original recorder failed. Execution results must be reviewed separately; force-teardown remains its separately controlled phase.
