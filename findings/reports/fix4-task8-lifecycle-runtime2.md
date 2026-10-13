# Task 8 lifecycle runtime harness fix 2

## Scope

Harness-only correction to the durable lifecycle helper and its SDD mirror. No product source was edited, no device command was run, and the controller-owned Android MCP session was not touched.

The pre-edit durable and mirror helpers are preserved separately under `.superpowers/sdd/2026-10-13-round4-fix-wave/task8-lifecycle-runtime2-base/`. Both snapshot files have SHA-256 `91b4849c52d00ad966bcecf7639169c3ebe019f5cb883aaeb2d3a25a1c1ab7ca`.

## Evidence finding

In `remaining-helper-attempt2`, the successful and failed log controls completed with their expected exits, reports, immediate log-child absence checks, and single terminal diagnostics. The interrupted control found its marked log child and immediately sent SIGINT. Its stderr reached `Running 1 flow(s)` but did not prove that the device-bound runner had started the long-wait generated flow. It exited 130 and passed the three immediate log-child absence checks plus the single-terminal-diagnostic check, then the helper failed while unconditionally opening an absent `interrupted-report/report.json`.

That is a harness timing/report-assumption failure. It is not evidence of a product regression.

The same failed attempt exposed a second harness failure during cleanup. The discovered local forward was `localfilesystem:/tmp/uia2-emulator-5580.sock`; the helper embedded its slash-containing value in an evidence filename before executing `adb forward --remove`, causing `FileNotFoundError`. The raw `cleanup.json` therefore does not prove that this forward was removed. The separate known product forward issue remains outside this fix.

## Changes

- The interrupted log control now waits for an exact live `grantiva-runner` process bound to the owned iOS UDID.
- Before SIGINT, it requires that runner's `--output` report directory to exist and its generated flow file to exist and contain `extendedWaitUntil`. The captured PID, report directory, and generated flow path are recorded in the check result.
- Exit 130, three immediate marked-log-child absence inventories, and exactly one truthful terminal diagnostic remain mandatory.
- Successful and failed cases still require their reports. The interrupted case validates status `interrupted` when `report.json` exists and truthfully records a null report status when the product emitted no final report.
- Forward-removal evidence filenames now use the existing alphanumeric `identity_token`; the exact discovered local forward remains unchanged as the final `adb forward --remove` argument.
- Background runner-report capture now treats an absent or zombie owned PID as an ended capture. It rechecks after an identity assertion race and still raises for any live PID whose argv is not bound to the owned device.

The durable helper and mirror are byte-identical with SHA-256 `78ac805c9838feb5189ec265ebab0e4b65cb56d5daf99a7069e7d2dfa9af3aac`.

## Device-free verification

Static focused checks and Python compilation passed for both copies. The checks verified:

- the long-wait runner gate includes exact executable, owned UDID, report-directory existence, generated-flow existence, and `extendedWaitUntil` content checks;
- SIGINT occurs only after that gate succeeds;
- an existing interrupted report must truthfully carry `interrupted` at top level or in a flow;
- successful and failed reports remain required;
- the forward label contains no path separators while the exact socket value remains in argv;
- vanished/zombie handling does not swallow a live PID ownership mismatch;
- durable and mirror helpers are byte-identical.

A live rerun is required for the lifecycle verdict. This report makes no cleanup-complete claim for `remaining-helper-attempt2`, because its raw evidence records the filename failure before forward removal.

## Runtime2 review follow-up

The two blockers in `task8-lifecycle-runtime2-review.md` were corrected without changing the prior report-status or forward-label behavior.

The interrupted runner binding now requires all of the following before SIGINT:

- the observed runner's PPID equals the current helper-spawned CLI PID;
- its PGID remains related to that launch as either the CLI process group or the direct child runner's own process group;
- its `--device` value exactly equals the owned iOS UDID;
- its resolved executable path exactly equals the installed runner path from the already validated frozen candidate manifest;
- the executable's current SHA-256 exactly equals the installed-runner SHA-256 in that manifest;
- its `--output` directory exists;
- its staged flow exists, has the same SHA-256 as this case's source flow, and contains `extendedWaitUntil`.

The retained `activeRunner` evidence now includes PID, PPID, PGID, originating CLI PID, executable path and hash, runner report directory, staged flow path, and flow hash.

The background report capture now calls `bound_argv_if_running`. If `ps_argv` raises `CalledProcessError` after the initial live probe, it probes liveness again. It returns only when the PID is then absent or zombie. A still-live argv read failure is re-raised, and a still-live device ownership mismatch remains an `AssertionError`. `CalledProcessError` was removed from the outer ignore list so a live failure cannot be silently swallowed.

### Focused commands and results

No-device Python tests imported the helper and constructed temporary frozen/staged artifacts plus synthetic `ps` rows. Results:

- `PASS exact current-case runner binding`
- `PASS unrelated parent/group, same basename, device, flow, and executable-hash negatives`
- `PASS vanish-between-probes race returns ended capture`
- `PASS live argv failure and ownership mismatch still raise`
- `PASS live bound argv positive`
- `PASS durable/mirror byte identity`

Both helpers passed `python3 -m py_compile`, and `git diff --check` passed for the durable helper. The final durable and mirror SHA-256 is `0db355fe5255212436181c1b636d72de3eb338bfea3c65425d10dff34d597ab4`.

The pre-review runtime2 durable and mirror helpers are preserved under `.superpowers/sdd/2026-10-13-round4-fix-wave/task8-lifecycle-runtime2-review-base/`, each with SHA-256 `78ac805c9838feb5189ec265ebab0e4b65cb56d5daf99a7069e7d2dfa9af3aac`.
