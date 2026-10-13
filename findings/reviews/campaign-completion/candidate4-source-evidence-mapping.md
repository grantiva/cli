# Candidate4 source-evidence mapping — Task4 preparation

Recommendation for controller ruling: reuse already passing source evidence by exact source identity; do not rerun Swift/Go suites, focused groups, vet or the L53 scratch build merely to rename the campaign. Current-tree full Swift results cover all explicitly named inventory tests. No source row verdict is assigned here, and no old runtime verdict is transferred. The old 2,024-test Swift run remains NONPASS historically.

No tests, builds, devices or network operations were executed for this mapping. Small read-only current-file hash/inspection and git diff checks were performed.

## Provenance joins

- Candidate4 manifest: `findings/evidence/completion-candidate4/candidate.json`, SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`.
- CLI merged73cfa99d94a00bbc0fd6fce13a7d72b9d9c29226 has the exact tree tested as77aa2a63064afc3a68d9ea71232f46e1937ba2ff. `task-2-final-acceptance-review.md` independently matched the tested source.patch against that commit; patch SHA `007c7ff6b5bf28a51a2eb1898a7d18032964ab60252380356b3ad92374dfe9c6`. Only SimulatorCapacity.swift, SimulatorManager.swift and four associated test files changed from6ba12ed3; none of the other focused-test groups or docs paths changed.
- `findings/evidence/fix5-L86-source/full/{start.json,result.json,stdout.raw.gz,stderr.raw.gz}` records the current-tree full suite: exit0, 2,027 passing test cases, API unset and distinct absent fresh runner homes. stdout uncompressed hash `2b64aa20d49e4fc6ae48cdfe0b3c687c12f1de3842634884e712029039e4aab0`; stderr `a07a6c31d99a64b7790b68b275252c4d34b0eff62356b8b3ccc1afe6106c739c`. The 84-test focused-corrected run addresses the actual L86 changes. Source/live approval and CI are linked through Task2 reviews and candidate4 merge-acceptance.json.
- Previous source closeout `findings/evidence/round4-coverage/source-window/closeout.json`, SHA `ccc9aef180b8e45d44ad7f75e8dddcf09567559aa0aa19e85d14a43453fb31f0`, supplies the exact 20-command/51-row mapping below. Its inventory is `findings/preparation/round4-coverage/task9-source-window-command-inventory-draft.json`, SHA `15437fda241ded594234cb4c59c0378eb50a595222945a6bc13d8d006894fc5b`.
- Runner ba9008f4b2cd2c7320a9c46e04faed612b0958a2 and demo84af7581b75134b0e417b254e4317d565f7b73c6 are unchanged. Candidate4 build/smoke reviews verify source cleanliness and exact retained artifact identity. This supports source/dependency provenance, not runtime coverage transfer.

## Twenty command requirements

The old command identifiers below are evidence requirements, not claims those literal invocations were newly executed on candidate4. Every explicit Swift test name in the inventory was matched to its passing current full-suite log record (63 references, 58 unique names). The old filtered runs remain exact filtered-command evidence; the current full run supplies execution on the new CLI tree. Under the instruction against repeating passing tests absent relevant changes, no additional filtered run is justified solely because the old inventory prescribed a filter spelling. If the controller retains an absolute campaign-fresh filtered-invocation rule, that is a provenance-policy choice to resolve explicitly, not a missing test execution hidden by this mapping.

| Command ID | Source evidence disposition | Joined rows |
| --- | --- | --- |
| `swift-l53-targets` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L53.E, B4-L53.F, B4-L53.P1, B4-L53.P4, B4-L53.P5 |
| `swift-l67-doctor` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L67.1, B4-L67.2, B4-L67.3, B4-L67.4 |
| `swift-l74-json` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L74.3 |
| `swift-l75-cycle` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L75.1, B4-L75.2, B4-L75.3, B4-L75.4, B4-L75.5 |
| `swift-l81-doctor` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L81.1, B4-L81.2, B4-L81.3, B4-L81.4, B4-L81.5, B4-L81.6, B4-L81.7 |
| `swift-l82-attachment` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L82.1, B4-L82.2, B4-L82.5 |
| `swift-l84-orphans` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L84.1, B4-L84.2, B4-L84.4 |
| `swift-l85-selector` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-L85.2, B4-L85.3, B4-L85.5 |
| `swift-pc5-launch-report` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-PC.5 |
| `swift-ej3-paths` | Current full-suite PASS; retained exact filtered PASS; no rerun | B4-EJ.3 |
| `swift-full` | New 2,027-test full PASS; old 2,024-test failure remains historical | B4-L82.1, B4-L82.2, B4-L82.5, B4-L84.4, B4-L85.5 |
| `go-l53` | Existing exact-command evidence on unchanged runner; no rerun | B4-L53.E, B4-L53.F, B4-L53.P1, B4-L53.P2 |
| `go-l83` | Existing exact-command evidence on unchanged runner; no rerun | B4-L83.1, B4-L83.2, B4-L83.4 |
| `go-pc9` | Existing exact-command evidence on unchanged runner; no rerun | B4-PC.9 |
| `go-pc10-13` | Existing exact-command evidence on unchanged runner; no rerun | B4-PC.10, B4-PC.11, B4-PC.12, B4-PC.13 |
| `go-inventory` | Existing exact-command evidence on unchanged runner; no rerun | package inventory prerequisite |
| `go-full` | Existing exact-command evidence on unchanged runner; no rerun | B4-L83.4 |
| `go-vet` | Existing exact-command evidence on unchanged runner; no rerun | B4-L83.4 |
| `go-l53-scratch-build` | Existing literal scratch build0 + empty-device64 on unchanged runner; no rebuild | B4-L53.P3 |
| `and-111-compile` | Candidate4-bound public compile/shutdown observation still required; not a unit-test reuse | AND-111 |

Go references are the corresponding `commands/<id>/{start.json,result.json,postflight.json}` under `source-window/go-focused` or `source-window/go-full-vet`; scratch has step-1/result.json and step-2/result.json. Package listing lives under go-inventory. All were previously independently reviewed in old SDD task9-go-full-vet-evidence-review.md, task9-swift-focused-go-evidence-review.md and task9-go-packages-review.md. Full Go used 26 reviewed literal packages (24 ok, two no-test packages), -count=1, separate cache from vet; vet exit0. These package successes do not establish every individual case was unskipped. Focused commands retain the exact four prescribed selections. The scratch executable was isolated and never substituted for the frozen runner; its build and empty-device diagnostic are already literal source-build evidence on the unchanged runner.

## Six source inspections

Prior exact summaries/files/reads remain under `findings/evidence/round4-coverage/source-inspections/<row>/`. Fresh current-file hashing during this mapping confirms their inspected files are byte-identical to candidate4 files:

| Clauses | Current source inspection binding |
| --- | --- |
| B4-L70.1/.2/.3 | README.md `740f44373d5006b51bfd7429decaf2004b9b7265f9b30e075fe1e1b2bd249ab1`; BaselineStore.swift `f50e09e5168de8b84828045ffea8d3327e77ba36a3ac0a2d2949aef7ea596912` |
| B4-L74.1/.2 | docs/mcp.md `0464d5dbec9e1aad0dc52535c11063c4277df4875cef75533b9caa0bb69dc0dd` |
| B4-L85.4 source half | PersistentTabContainer.swift `42a57d629918c00a8abc06ef61e6efe31457317436ea08c5ceed2b3b1f8b593b`; ContentView.swift `3df186effd86eb7dd9e279ffc50e1813878e67e56d4871ff52cbe1a75fb59427`; Navigator.swift `65f81e6cedc3b28de0ff91efd3df40f5863433f56d329d58b916b9c4725f0e55` |

The small fresh read confirms ISO8601 UTC script-consumption documentation, canonical percent escaping and current-first/legacy-fallback filename logic, plus public UITab/UITabBarController persistent hosts and heart identifier. This is a current-path join to the unchanged detailed inspection, not a new claim about live labels/geometry or retention. No additional source inspection command is needed for these six clauses. L70.3 still needs its migration-evidence provenance join; L85.4 still needs owned iOS26 semantic-back and switch-away/back runtime evidence.

## Remaining work, without redundant source reruns

No missing unit-test, full-suite, vet, package-inventory or L53 scratch-build execution is identified. The formerly failed full-suite components for B4-L82.1/.2/.5, B4-L84.4 and B4-L85.5 now have independent current-tree passing full-suite evidence; this does not change their old records or grade their runtime clauses.

AND-111 is the one old command inventory item that is inherently candidate-binary/device-state acceptance: literal `[candidate4 CLI, "build", "build"]`, no --device, in the reviewed scratch Android project while the exact campaign-owned AVD is registered and shut down, with before/after state proof and compile-only confinement. Candidate3's compile used a different CLI hash and cannot supply that candidate4 runtime clause. It is not necessary to rebuild the runner or demo merely to establish unchanged dependency identity; this distinct CLI compile behavior still needs the controller's authorized candidate4 capture. No execution is authorized by this report itself.

Public frozen CLI/installed-runner empty-device64 (L53.E/P3), L53 live/install controls, ambiguous doctor/run public behavior (L67), actual session JSON (L74.4), CLI path-spelling cycle controls (L75), live doctor output (L81.3), PC.5's owned running-to-passed half, EJ.3's two platform halves and L85.4's semantic/live retention clauses remain separate slice joins. Some have current Task3 smoke evidence, but this source mapping does not assign or transfer those runtime verdicts. Route each pending clause from the old closeout to its exact current capture or future slice instead of re-running a passing source suite to compensate.

Controller action needed is a provenance ruling accepting these source-level joins and preserving literal runtime requirements. If a later actual source change, failing result, skipped named case or relevant concern appears, reassess only the affected source scope. The old Swift NONPASS and all first failures remain immutable evidence.
