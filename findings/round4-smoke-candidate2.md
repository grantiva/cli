# Round 4 candidate 2 smoke — pending

Task 8 is not complete. Candidate 1 remains failed and its raw evidence and verdicts are unchanged. This report will record the complete replacement-candidate smoke; Task 9 execution remains gated.

## Source and packaging gates

- CLI repair PR213 merged as `d28bd212d7a5e67a3d92c05bde83d474a56c4a52`.
- Runner repair PR27 merged as `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`.
- Demo repair PR5 merged as `84af7581b75134b0e417b254e4317d565f7b73c6`, following complete independently approved iOS 26 and 27 regression and owned-device cleanup.
- Package PR214 reviewed at `53b34ea38a82426a8dfd150fa64911ebbdb901aa`: independently approved specification and quality; CI run `38459262712` passed and PR merged as `22055ff981ae1ffd5aaae69190d7af180f239162`. Frozen runner version `1.1.28-grantiva.15`, install stamp `1.1.28-grantiva.15+android-drivers-2`.
- Fresh merged-demo iOS and Android builds passed; exact provenance and artifacts are in `findings/evidence/round4-smoke-candidate2/build-inputs/`. The iOS build wrapper's transient concurrent-Android status observation is preserved and qualified after both builds became clean.

## Prepared execution

The 8,593-entry byte-identical APFS clone under `/private/tmp/grantiva-round4-candidate2-ciz5f2kj/runner-home` was upgraded successfully, preserving all 8,069 existing cache entries and verifying all 800 packaged WDA files. A clean release build from merged CLI `22055ff9` produced QA binary SHA256 `33c62e613703ddbd701a178028e099677b900deb003dceb02c74d86214555c37`. Candidate manifest SHA256 is `6c0a8bd9da5cff886baf9aceb58394e6ca1632b5b3b10f6aa1bb066aa50be14e`. Independent freeze review is APPROVED. Candidate 2 provisioning passed: owned iOS 26.0 simulator `553C67C6-7C11-4976-85A0-148C9C8AC278` has the exact frozen app installed, and owned `smoke4-android` is `emulator-5580` with provision PID `21620`. The Android runner smoke is in progress.

The initial documentation capture stopped at 150 help pages because its helper did not accept the comma delimiter in `flags, featureflags`; the 22 omitted pages all belong to that canonical command group. The failed raw capture and executed helper remain under `06-docs-output/`. This is a helper parsing gap, not a product finding. The corrected helper passed scoped review. Fresh `06-docs-output-attempt2/` passed all 172 help pages, normal and ambiguous doctor text/JSON, public migration note inspections, and all 16 corpus tests with zero failures and an empty isolated test home afterward.

Reviewed controller and helper sources are archived in `findings/tools/round4-smoke-candidate2/`, with per-file hashes. The final run must cover all original Task 8 phases plus the L82/L83/L84 joint forward controls, then physically remove only its newly owned devices and receive independent acceptance review.

Completed documentation and provisioning evidence received independent APPROVED review. The final physical-cleanup helper also passed scoped review after its PID-reuse guard was corrected; execution remains pending until live smoke ends.

The first Android phase stopped on a helper assertion after healthy, crash 5/5, gesture 4/4, favorite removal 5/5, and literal clearState/bare stopApp passed. `dumpsys window windows` omitted `mCurrentFocus`, so the focus assertion had no field to inspect. Additive `02a-stop-focus-diagnosis/` captures full `dumpsys window` with Settings focused, Settings-only UI hierarchy, and Landmarks process absent. Independent diagnosis confirms the restricted window-dump output caused a helper false negative; no product defect is evidenced. The first phase failure remains preserved and no Android phase acceptance is claimed. A corrected fresh-output full rerun is being prepared. Meanwhile, the non-force lifecycle phase is running serially on the owned devices.

The first non-force lifecycle attempt stopped because the log-flow helper omitted `--platform ios` in a dual-config project; the CLI correctly rejected the ambiguity. Startup interrupts, detach/ready controls, ready interrupts, and absent-app controls passed before that stop. A secondary background report-copy race on `report.json.tmp` is also preserved in stderr. Helper corrections and a fresh full lifecycle rerun are required. The packaged joint-forward phase is running serially next.

Packaged joint-forward smoke passed all four cases with invocation exit 0, both unrelated controls preserved, and exact owned forward/process/session cleanup. Independent raw review is pending. Full iOS MCP smoke is now running.

The first iOS MCP attempt passed L65 and the selector sequence including selected/unselected literal heart and Name placeholder, then stopped on an expected-prefix assertion after the quoted Mount Denali tap itself succeeded. The helper appears to expect literal escape backslashes in already-decoded text; independent classification is pending. Runner stop exited 0. Full Android MCP smoke is running serially.

Independent packaged joint-forward review is APPROVED. Full Android MCP phase passed, including L65 and ten mixed large-response pairs; final runner stop exited 0 and its session is absent.
