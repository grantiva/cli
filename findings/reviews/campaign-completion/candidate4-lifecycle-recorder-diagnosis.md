# Candidate4 lifecycle recorder diagnosis

Disposition: recorder failure, not demonstrated product failure. Preserve the original invocation exit 1, failure.json, checks.partial.json and raw files unchanged. The lifecycle acceptance gate remains unsatisfied.

Reviewed only the retained lifecycle captures and the relevant helper paths; no code, device, build or test changes or reruns were made.

## What happened

Both startup-interrupt checks completed and are retained: iOS runner PID42479 and Android PID42490 were observed starting and their foreground commands exited130. The next phase reached iOS detached start. PID42588 was authenticated from the session and exact device-bound runner argv. Concurrent repeat-start JSON says already_running with that PID and null port; plain output explicitly says starting. The original detached CLI PID42560 then exited0 with status:started, PID42588 and port8930.

While the normal detached-start return was removing its temporary launch workspace, the report worker raced that removal. copy_report_snapshot checks existence and then copytree; existence is not a lifetime guarantee. The retained traceback is a shutil.Error whose source is the authenticated report root itself, ENOENT. Existing handling accepts only disappearing .tmp entries, so root disappearance propagates through the worker's saved error and stop_report_snapshot, before terminal metadata and ready/hierarchy assertions. This matches legitimate launch-report cleanup already recognized by the helper's terminalReportAbsent design/comment; it is not evidence that the successful app launch or runner became unhealthy.

## Retained report can qualify its narrow clause

Yes: the existing report is complete and can legitimately satisfy the **retained successful launch-report** clause without overwriting or converting the failed helper invocation. report.json has status:passed, nonempty endTime, summary total1/passed1/failed0/skipped0/running0/pending0; its sole flow is passed with endTime and two passed commands. The referenced flows/flow-000.json exists and records completed launchApp and waitForAnimationToEnd commands with no missing artifacts. It binds the expected Landmarks bundle, iOS UUID8BE033F1-0455-4BE3-A083-3132222D63C6, and the same authenticated grantiva-session-313DB7B4-B7FC-4D9F-A615-B715A3D96BBF source path; the generated YAML is retained. Report SHA-256: `acea3f125a0ae3d1020ff787b04b729506ea8387b56b45178e076ef8bcc74b2a`.

This is direct retained-byte evidence, not reconstruction from an exit code. It does not repair the missing worker terminal-state record or establish every detach-ready assertion.

## What remains missing

The exception occurs before the ready session is read and before immediate dump-hierarchy. There is no retained ready-session snapshot validated against the returned PID/port, no immediate hierarchy proof for this detached generation, and no normal phase stop/PID/shared-session cleanup assertions. Failure cleanup does retain an exit0 stop reporting status:stopped for PID42588 and an empty Android forwards list. cleanup.json has only that stop action; it is best-effort cleanup evidence, not the omitted normal acceptance checks or a dedicated retained final absence inventory.

Android detach-ready, both ready-state foreground-interrupt controls, and all later selected lifecycle phases were not reached. checks.partial.json correctly contains only the two startup-interrupt checks; no detach-ready PASS can be inferred from the preserved report alone. Failure cleanup has already ended the iOS detached generation, so a future hierarchy command cannot retroactively prove its immediate readiness.

## Minimum correction and resume

Correct only the recorder's authenticated source-disappearance path: recognize ENOENT for the known ephemeral report root/subtree as an observed cleanup race, proceed to joined terminal recording, and validate the previously retained complete report/flow. Do not blanket-ignore other copy errors, permission failures or malformed/incomplete retained reports. Retained-byte validation must remain mandatory for report-required calls; a missing source without complete retained proof remains a failure. Preserve the original complete snapshot from subsequent partial-copy damage. A small deterministic fake-copy regression can cover root disappearance after a complete retained report and refusal when no complete report exists; no product change is justified by these records.

After scoped correction/review, use a new adjacent output directory for detach-ready on both platforms, including its ready-state interrupt controls, then the unexecuted remaining selected phases. The two completed startup-interrupt checks and this report's narrow successful-launch proof may be retained as first-attempt evidence; they need not be erased or relabeled. Because the helper exposes phase-level rather than platform/substep resumption, an adjacent detach-ready phase invocation is the minimum existing executable scope that collects the missing iOS ready/hierarchy/normal-stop proof and Android/control coverage. Later live phases remain held until that recorder correction is accepted.
