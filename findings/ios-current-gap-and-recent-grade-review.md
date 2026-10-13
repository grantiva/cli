# iOS current-evidence gap audit and recent-grade review

Scope: read-only review of retained round-3 evidence for still-missing iOS rows, plus the recent iOS attempt 23/24/24b and Android AND-118/119 grades. Candidate source is `release-main` at `8f2cff67`; runner source is `release-round3b` at `fd9d8e8`. I did not alter either platform ledger.

## Provenance boundary

I excluded `cov3-ios-historical-cov2-import` completely. `cov3-ios/PROVENANCE.md` says the pre-import top-level inventory is reconstructed from an agent transcript rather than a contemporaneous raw capture and discloses four overwritten stable-name files. I therefore did not propose a new grade from those top-level groups. The audit below uses the independently named attempt directories, frozen helpers, command records, reports, and raw MCP streams. Where a display transcript truncates a response, the cited `mcp/stdout.raw` is authoritative.

## New missing-row candidates

There are **no additional whole rows that can honestly be graded from the retained evidence alone**. The strongest reusable evidence is already represented in the ledger. The following near-candidates are useful joins, but each still lacks a binding clause; they must remain ungraded until that clause has current-round proof.

| Row | Retained current-round evidence | Missing binding clause |
|---|---|---|
| X-001 | iOS `cov3-ios-attempt10/pass-plain.out` and Android `AND-106` prove stock success | Android evidence does not preserve the exact text-output comparison required for same narration structure. |
| X-002 | iOS `cov3-ios-attempt10/pass-json.out` and `fail-json.out` | No retained Android passing-and-failing JSON pair with the exact cross-platform key/type comparison. |
| X-003 | iOS `cov3-ios-attempt10/pass-report/` and Android `AND-106` reports | No explicit cross-platform schema/name/path comparison; Android stock success alone is insufficient. |
| X-004 | Android `cov3-android/X-004/` has passed/failed/interrupted ready files | No current-round iOS three-state ready-file set joined to it. Attempt 15 evidence is row-specific but must be audited as a complete three-state set before grading. |
| D2-18 | iOS attempt 10 has pass/fail JSON | The required pre-flow bad-device object and full Android pass/fail/pre-flow shape set are absent from this join. |
| B2-K18 | iOS attempt 10 contains no-report and preserved-report output | Exact criteria also require run/diff-capture/ci-run suppression behavior on both platforms and semantic source-test proof. Existing evidence covers only part. |
| B2-K93 | `cov3-ios-attempt23/04-crash-no-hint.*` and attempt 10 failure remediation | Build-error negative and Android parity remain missing, as already disclosed by provenance. |
| X-021 | iOS `cov3-ios-attempt16c/mcp/stdout.raw` and attempt24b raw contain complete tool results | A row-level, same-operation cross-platform shape comparison is not preserved; isolated successful calls do not establish all listed tools. |
| X-022 | iOS `cov3-ios-attempt22/mcp/stdout.raw` contains no-session VRT operations | Required live-session and Android counterparts are not a complete exact input/result pair. |
| D2-41 | attempt22 gives iOS no-session VRT; attempt24/24b gives live MCP transport | The row requires the specified VRT operation/error matrix on both platforms; these attempts do not cover it completely. |

This audit also found no ungraded IOS build/input-form row that could be promoted merely by reusing attempt 10–24b. The exact IOS-065/066/067/070/071/074/084/085/087/104/114/115/116/138/140/152 and B-I06.1 evidence has already been graded. The remaining build/input rows need a distinct input variant, negative, lease, or lifecycle clause rather than another reference to the same successful run.

## Scoped recent-grade review

### iOS attempt 23/24/24b

Approved with no material unsupported criterion found.

- B2-K81 and B2-K82-a correctly join attempt 23's missing snapshot variants to attempt 10 and the exact-head semantic source package. The provenance explicitly limits what each capture proves.
- IOS-114 is supported by `cov3-ios-attempt24/requests.json`, `mcp/transcript.txt`, and `mcp/shell-01.exit.txt`: the malicious-looking screen name remains one argument, returns an application error, does not create `/tmp/pwn`, and the server continues.
- IOS-115 is supported by `cov3-ios-attempt24b/mcp/transcript.txt`; all five required-argument names and the unknown tool appear, with successful intervening/final `tools/list` responses.
- IOS-116 is supported by the frozen attempt24b harness and transcript: both configs exist, runner and MCP select iOS explicitly, readiness succeeds on owned U1, live script/type calls succeed, and the owning project stops its session.
- IOS-104 and B-I06.1 correctly cite `cov3-ios-attempt24b/mcp/stdout.raw`, rather than the truncated display transcript. The raw response contains the exact `Yosemite` request result, updated tree, and focused Name value `Golden Gate BridgeYosemite`.

### Android AND-118/119

AND-118 is supported. `AND-118-exact-rerun1/commands.txt` records no configured emulator and no device flag; `stderr.log` contains explicit `device=(none)` and then the selected emulator, while `stdout.log` and the preserved report show the flow passed. No empty serial is claimed.

AND-119's verdict is supported by the raw artifacts. `fail/stdout.log` shows the named screen failure followed by a passing browse flow, and the command exits 1. `slow/report/flows/flow-000.json` records a terminal failure with the exact configured-30-second timeout and names screen `Slow`. One wording correction is advisable: the ledger currently says “after 34.2 seconds wall time under the 30-second cap.” Total process wall time cannot be under a 30-second cap when it is 34.2 seconds. Say instead: **“the screen timeout fired at its configured 30-second cap; total command wall time, including setup/cleanup, was 34.2 seconds.”** This is a precision correction, not a grade change.

## Verdict

The seven newly reviewed iOS grades and AND-118 are supported. AND-119 is supported with the wording correction above. The retained current-round corpus supplies useful partial joins for ten missing rows, but zero new whole-row grades without additional exact evidence.
