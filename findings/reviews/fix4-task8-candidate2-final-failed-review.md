# Task 8 candidate 2 — final failed closeout review

## Verdict

**Specification verdict: APPROVED AS FAILED.** The closeout accurately records candidate 2 as failed by confirmed product finding L85, reopens L66, records the unexecuted remainder of iOS transport as `NOT RUN`, and keeps Task 9 gated. It does not regrade the candidate after the failure.

**Evidence and quality verdict: APPROVED.** The final force phase and physical cleanup are complete and bounded. The governing report, L85 brief, retained phase reviews and raw closeout evidence agree. No blocking inconsistency or unsupported success claim was found.

## Force teardown

`07-final-force-teardown/invocation/result.json` records exit 0 with the frozen candidate manifest SHA-256 `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`, exact owned iOS UUID, `fix4-8`, isolated runner home and unset API environment. `helper/acceptance.json` is `passed`, records the runner session stopped and owned device home removed, and truthfully leaves `physicalDeviceDeleted: false` with final cleanup required. This is the required force behavior and does not conflate resource reclamation with physical simulator deletion.

## Physical cleanup

The initial `08-final-cleanup/acceptance.json` is preserved as failed. It records successful exact iOS shutdown/delete and Android stop, then conservatively refuses two simulator-managed marker processes and AVD deletion because the generated config lacks the helper's expected legacy identity keys. `unknown-marker-processes-before.json` identifies only the owned simulator's `launchd_sim` and installed Landmarks process. The helper did not directly signal them; exact simulator lifecycle operations removed them. Its post-operation process inventory contains no owned UUID, AVD, serial, or PID marker.

The AVD continuation has adequate ownership binding:

- `provision/ownership.json` records successful creation of `smoke4-android`, Android 35, with Java 21, and `provision/avds-before.stdout` proves the name was absent from the baseline.
- The retained `.ini` fixes the exact path and `path.rel` to `smoke4-android.avd`; the generated config contains `avd.id=<build>` and `avd.name=<build>`, explaining why legacy-key validation refused it rather than manufacturing identity.
- `08-final-cleanup-continuation/delete.json` invokes only `avdmanager delete avd --name smoke4-android`, under the recorded Java 21 home, and exits 0; stdout confirms that exact AVD was deleted.

Fresh `08-final-cleanup-verification/acceptance.json` passes with `actions: []` and no failures. Its raw inventories establish that iOS UUID `553C67C6-7C11-4976-85A0-148C9C8AC278`, Android serial `emulator-5580`, AVD `smoke4-android`, owned PID `21620`, owned/marker processes, project/global sessions, leases and forwards are absent. Only baseline `Pixel_8_API_35` remains in the AVD list.

Protected state is unchanged: both protected booted simulator records equal the pre-provision inventory after excluding only dynamic data/log sizes, including UUID, type, name, state, paths and last-used metadata. The protected Pixel config SHA-256 remains `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`.

## Governing result and L85

`findings/round4-smoke-candidate2.md` accurately carries forward the independently reviewed phase outcomes and preserves all diagnosed first attempts. Its iOS result matches the raw attempt-3 evidence: the real `Landmarks` BackButton, same-named application root and selected tab coexist; semantic `Landmarks` reports success but Mountains remains visible. The delayed screenshot rules out transient snapshot lag. Frozen candidate source at `Sources/GrantivaCore/WDA/WDAClient.swift:249-299` excludes the application root but accepts the first remaining broad label result (`elements.first` at line 285), leaving the back button and selected tab ambiguous.

The new L85 brief gives the failure a precise owner and replacement-candidate acceptance contract. It preserves label → identifier → placeholder priority and all surrounding selector/error/retry/transport/demo obligations, requires a meaningful competing-element-ID test, and requires the complete Task 8 smoke on a newly merged and frozen CLI. It does not permit coordinate substitution, demo-label changes, or candidate-2 regrading.

Because attempt 3 stopped at L85, the report correctly marks the subsequent iOS large/small transport portion `NOT RUN`. The Android MCP transport pass cannot substitute for that platform-specific execution. Candidate 2 therefore cannot satisfy Task 8, and Task 9 must remain gated.

## Scope

This was a bounded read-only review of the finalized report, L85 brief, raw force/cleanup records, ownership and baseline evidence, and prior approved phase verdicts. I did not execute device commands, rerun passed phases, or review the separate uncommitted product fix.
