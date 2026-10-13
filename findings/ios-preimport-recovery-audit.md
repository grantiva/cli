# iOS permitted pre-import recovery audit

## Boundary applied

This audit accepts the controller's stated provenance boundary. The 20 top-level groups enumerated in `cov3-ios/findings/evidence/cov3-ios/PROVENANCE.md` are eligible current-round evidence even though `pre-import-top-level-inventory.txt` was reconstructed from the original agent transcript rather than captured contemporaneously. The quarantine remains excluded. The four overwritten stable paths must use the byte archive under `cov3-ios-prior-commit-9542e3d4`; none of the candidate mappings below depends on their current replacements.

I did not reject evidence merely because its inventory was reconstructed. I inspected the eligible `STEP1`, `STEP2`, `IOS-117`, `IOS-119`, `IOS-120`, `FLOWS-26`, and `FLOWS-27` bytes and their retained command records. Result: **zero additional complete missing IOS/B-I/D2 rows can be graded solely from these groups.** They contain several useful clauses, but the complete rows are either already graded or require variants/proofs absent from the eligible bytes.

## Already graded complete rows confirmed

| Row | Eligible current-round evidence | Conclusion |
|---|---|---|
| IOS-117 | `cov3-ios/IOS-117/commands.txt`, `stock-26.out`, `stock-26.err` | Complete and already graded: 5/5 screens, 12/12 flows, cached iOS 26 agent. |
| IOS-119 | `cov3-ios/IOS-119/commands.txt`, `crash-26.out`, `crash-26.err` | Complete and already graded: exit 1, first assertion reports crashed/not running, failure screenshot named. |
| IOS-120 | `cov3-ios/IOS-120/commands.txt`, capture outputs and both `shots-*` sets | Complete and already graded: five correct configured screens on 26 and 27. |
| IOS-203–239 | corresponding `FLOWS-26/*`, `FLOWS-27/*` outputs and reports | These flow-command rows are already represented in the active ledger. The recovered groups are valid current-round evidence; no new row is missing here. |

## Useful partial joins for still-missing rows

| Missing row | Supported clause | Exact eligible evidence | Why the whole row remains open |
|---|---|---|---|
| D2-02 | Passing stock screens+flows has separate screen/flow totals and artifacts. | `IOS-117/stock-26.out`, `stock-26.err` | No retained `--ready-file` document or explicit `--report-dir` from this group. |
| D2-04 | Flow reports retain command/step structure and screenshots. | `FLOWS-26/01-browse-report/report.json`, `02-exact-negative-report/report.json` | No exact `--snapshot trailing` and `--snapshot full` pair with report asset inventories. |
| D2-05 [ios] | File and inline `runFlow`, waits, scrolling and subflow execution work live. | `FLOWS-26/14-runflow.*`, `14b-runflow-inline.*`, `08-scroll.*`, `09-waits.*` and matching reports | Not one Maestro-format screens config exercising every required form; no retained subflow-screen capture proof. |
| D2-18 [ios] | Passing flow result and failing exact-selector result retain ordered steps and error detail in runner reports. | `FLOWS-26/01-browse-report/report.json`, `02-exact-negative-report/report.json` | These are runner reports, not the required `run --json` stdout shapes; pre-flow bad-device JSON is absent. |
| D2-19 [ios] | Plain no-report run prints the exact “Report not kept” notice without exposing a temp report path; stock/failure output exists. | `IOS-117/stock-26.err`, `IOS-119/crash-26.err` | No quiet/JSON/JSON+verbose passing-and-failing mode set in the eligible groups. |
| B-I02.1 | Explicit U1 and U2 capture invocations each produce five correct screen PNGs. | `IOS-120/commands.txt`, `shots-26/`, `shots-27/` | Criterion also requires proving the other simulator was untouched during each repro; no before/after device-state capture. |
| B-I02.2 | Explicit simulator selection works for both owned devices. | `IOS-120/commands.txt`, capture outputs | Missing config-over-session precedence and ambiguous-many-booted negative. |
| B-I04.1 | App-owned discard flow succeeds in both runtime groups. | `FLOWS-26/04-discard.*`, `FLOWS-27/04-discard.*` | The brief requires ten reruns; attempt 28, already graded, supplies those. |
| B-I04.2 | System alert is accepted on both runtimes while discard flow remains explicit. | `FLOWS-26/21-system-alert-maps.*`, `FLOWS-27/21-system-alert-maps.*`, both `04-discard.*` | Runner CHANGELOG/source is needed for the documentation/design clause; the active attempt-28 row already joins it. |
| B-I05.2 | Quote-containing visible label `Mount "Denali"` works in stock flow execution. | `IOS-117/stock-26.out`; `FLOWS-26/12-quote-label.*` is not present as a standalone group, so only the stock transcript is eligible | This is runner-flow tap behavior, not the required MCP predicate/class-chain label-first plus name fallback semantics. |
| B-I06.2 | Unicode and ordinary input reach app fields intact. | `FLOWS-26/15-input-unicode.*`, `03-edit.*` | No retained WDA request path proving `/wda/keys` or conditional `/keys` fallback. |
| B-I07.1 | Caching flow produces the expected UI actions. | `FLOWS-26/08-caching.*`, `FLOWS-27/08-caching.*` | Commands did not use `--logs`; app-line volume and banner filtering cannot be inferred. |
| B-I13.1/B-I13.2 | STEP2 created and booted named 26/27 simulators and installed/launched on each. | `STEP2/commands.txt`, `ensure-*.{out,err}`, `install-*.{out,err}` | No ten-iteration create/delete durability loop or ledger-cleanliness snapshots. |

## Reconstruction limitations

- `STEP1/ensure-*` and `STEP1/install-*` are explicitly historical additions and were excluded. Only its original command ledger, booted lists, doctor, source check, device types, and tools-list files were considered.
- The recovered command files use the old scratch cwd and shell variables. They establish what was invoked because each ledger resolves U1/U2 and names output files, but they do not provide a frozen helper script or a contemporaneous full-file inventory.
- No claim is made from the quarantined round-2 tree or from the old round-2 result ledger. Similar old row descriptions were used only as search hints; every mapping above was checked against current retained bytes and the round-3 matrix.
- The eligible flow groups are strong runtime evidence, but they cannot fill source-only criteria or omitted negative/input variants by implication.

The useful action is to join these partial clauses when a fresh or exact-head source package supplies the named missing clause. None should be promoted to a full-row pass by itself.
