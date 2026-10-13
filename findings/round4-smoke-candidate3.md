# Round 4 smoke — candidate 3

Status: **IN PROGRESS**. Task 8 has no zero gate; Task 9 has not executed.

Candidate manifest: `findings/evidence/round4-smoke-candidate3/candidate.json`, SHA-256 `e9cfc7dce72ba8125b7c55df8d3dec355925003de24a4131c6510b9e67c51ebf`.

- CLI merged `6ba12ed37658228a3ce87cb64e1f5d88dda38e07`, QA binary SHA-256 `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`, version2.1.0.
- Runner `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, .15, packaged and installed SHA-256 `9342b8a3d17b9063c399ecab6cd8681cefa3bce91a21de65473147b54ef9a37b`.
- Demo `84af7581b75134b0e417b254e4317d565f7b73c6`, fresh iOS and Android builds.
- Scratch `/private/tmp/grantiva-round4-candidate3-9lkulx9q`; session `fix4-8-c3`.

| Phase | Result | Review |
|---|---|---|
| Fresh merged build, promotion, upgrade, freeze | PASS | Independent APPROVED |
| Docs/output:172help pages,16tests | PASS | Independent APPROVED |
| Owned provisioning | PASS | Independent APPROVED |
| iOS MCP selectors and transport | PASS | Independent APPROVED |
| Android runner | PASS | Independent APPROVED |
| Lifecycle | PASS, fresh attempt3; two prior helper failures preserved | Independent APPROVED |
| Joint forwarding ownership | PASS | Independent APPROVED |
| Android MCP | PASS | Independent APPROVED |
| Final force teardown | Helper copy race before force command; foreground fixture preparation | Pending |
| Physical cleanup/protected inventory | Not run | Pending |

No prior candidate grade populates this table. Candidate1 and candidate2 remain failed. L85 source-live first iOS26 Cancel hierarchy timeout remains unreproduced and recorded in `findings/evidence/fix4-85`; full iOS26 source retry and iOS27 passed, but candidate3 must complete the whole frozen smoke sequence. Any recurrence is triaged rather than retried until green.

Provisioning ownership records bind `smoke4-c3-ios` UUID33BCE8AB-B7F2-4D47-B0B8-2CB1D8A1971E and `smoke4-c3-android` emulator5580 PID61153. Physical cleanup remains mandatory.

Lifecycle attempt2 used independently approved helper `38a48f3765fd4615f483f066ed6519da0f9fa31746f52aa3dd66dc37ed21e0d9`. Both startup-interrupt cases passed (iOS PID69300, Android PID69312, exit130). Detached iOS retained a complete passed launch report, but the helper required its temporary source to still exist at terminal capture and failed. Original raw remains under `03-lifecycle-attempt2`; no full lifecycle pass. Failure cleanup stopped exact PID69412 with exit0, and controller ps confirmed all three PIDs absent. Round-5 author correction and independent review are required before a fresh retry.
