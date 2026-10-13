# Review — round-3 triage drafts L64 and L65

Scope: read-only validation of the two controller-written triage drafts against their cited slice evidence, the binding B3-L57/B3-L15.2 matrix rows, and shared round-3 rulings. This reviews issue accuracy only; it is not a campaign-completion judgment and does not propose product fixes. No device command was run.

## L64 — Android launchApp can still pass after a matching fatal crash

### Evidence and chronology: supported

The two claimed violations are accurately identified:

- CF-crash1: matching PID 10863 logs FATAL at `02:33:04.904`; the final launch status at `02:33:05.596131` still says `pids [10863], drawn=true crashed=false`; `launchApp` completes successfully at `02:33:05.596303`. The draft's 0.692 s delay is correct at displayed precision. The following assertion fails with `app_crash` at `02:33:06.830742`, 1.927 s after FATAL.
- CF-crash2: matching PID 11278 logs FATAL at `02:33:29.392`; the final launch status at `02:33:29.604413` says `pids [11278], drawn=true crashed=false`; `launchApp` completes successfully at `02:33:29.604464`. The draft's 0.212 s delay is correct. The following assertion fails with `app_crash` at `02:33:30.627404`, 1.235 s after FATAL.

The comparison-run description is also correct. CF-crash3 and CF-crash5 fail at `launchApp`. CF-crash4 completes `launchApp` at `02:34:44.796975`, before its FATAL at `02:34:44.832`, then fails the next assertion. The draft properly excludes CF-crash4 from the fatal-before-return defect.

The raw flow verdicts are failed in every run, so the draft correctly limits the defect to step attribution/timing rather than claiming an overall false pass. The cited FATAL-to-failure delays remain inside the accepted two-second bound.

### One important scope clarification

The draft's issue acceptance is intentionally narrower than the binding B3-L57 campaign criterion. The matrix and shared ruling require `launchApp` to fail on a dead process and the matrix's five-run check says each captured run fails at `launchApp`. The draft instead permits a crash after a successful return to fail the following step. That distinction is sensible for isolating the demonstrated race, but it must not be read as regrading B3-L57 or replacing its campaign expectation.

Add one sentence such as: “This issue isolates the two fatal-before-return violations; its narrower acceptance does not revise the current B3-L57 matrix grade or criteria.” Keep CF-crash4 as comparison evidence, not as a third instance of L64.

The draft correctly preserves the withdrawn wall-time target as withdrawn. It does not reopen that target. Its suspected-cause paragraph is clearly labeled inference and appropriately asks for source confirmation.

### Candidate/campaign status: correctly qualified

The candidate identifiers match the campaign provenance: CLI `8f2cff67`, runner `fd9d8e8` / `.13`. The status explicitly says evidence-backed triage during an incomplete pass and not a round-completion statement. Evidence paths currently living only on `cov3/android` are disclosed.

Disposition: **supported with the scope clarification above**.

## L65 — missing script steps error contract

### Exact contract and live evidence: supported

The binding shared ruling says a missing required argument must use `Error: Invalid argument: '<name>' is required.` B3-L15.2 makes the live-session texts exact for script, swipe, and type.

The cited iOS transcript request IDs and responses match the draft:

- ID 2, `grantiva_script {}`: `isError: true`, exactly `Error: Invalid argument: 'steps' array is required.`
- ID 3, `grantiva_swipe {}`: `isError: true`, exactly `Error: Invalid argument: 'direction' is required.`
- ID 4, `grantiva_type {}`: `isError: true`, exactly `Error: Invalid argument: 'text' is required.`

Each has one `Error: ` prefix. The observed script difference is exactly the extra word `array`; the draft does not overstate the other tools.

The source/test citations are accurate at candidate source `8f2cff67`: `ScriptTools.swift` constructs the observed array variant, `ToolErrorContractTests` expects it through ToolRegistry, and `ScriptToolsTests` checks it directly. The draft correctly explains that source/test agreement does not satisfy the separately approved exact L15 text.

### Platform and status scope: correctly qualified

Only iOS live behavior is directly evidenced. The draft says “ios observed; shared MCP implementation, Android live verification pending,” which accurately separates observation from a cross-platform source inference. Its acceptance criterion may require both live platforms because the matrix platform is both, but the Actual section must continue to describe only the observed iOS failure until Android evidence exists.

The no-session precedence sentence is consistent with B3-L15.1 and does not substitute no-session evidence for this live-session row. The status says the campaign is incomplete, and the evidence-location note makes clear that the capture is not yet merged.

Disposition: **supported as drafted**.

## Overall disposition

Both drafts are evidence-backed candidate triage, not completed-campaign conclusions. L65 is accurate as written. L64's facts, timestamps, and withdrawn-target handling are accurate; it needs only an explicit statement that its focused fatal-before-return acceptance does not supersede the broader binding B3-L57 campaign criterion.

## L64 clarification rereview

The draft now states: “These criteria isolate the observed defect. They do not replace, relax, or regrade the binding B3-L57 campaign row; its full five-run criterion and other accepted requirements must still be verified separately.” This directly resolves the scope concern. It preserves the issue's focused fatal-before-return analysis while leaving B3-L57's grade and full campaign criteria intact. **ADDRESSED.**
