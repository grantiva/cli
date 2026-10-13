# Round 4 bounded smoke — in progress

Candidate CLI `fb7af9d1702cd4f294aae48eb5f1ed52dbfe2d88`, runner `ff68658f73e4b6d9d94897d99ad1a0a270a105b7` / `1.1.28-grantiva.14`, demo `1552ae983a27528eff4c1f8145aa075698b47f71`. Candidate identity and all raw evidence are under `findings/evidence/round4-smoke/`. No full smoke or coverage pass is claimed yet.

- Release build: passed; QA binary SHA256 `9519a249d854f70e9dc6da2703b9db33a01166ee18bdf3b7938efa901083efa8`. Previous QA binary/resources retained in the task scratch backup.
- Fresh APFS clone upgrade: passed; 8,593 source entries cloned identically, 8,069 existing cache entries preserved, four new WDA configurations with 200 files each match the Task 7 manifest. Governing native extraction handles macOS AppleDouble metadata correctly; initial Python extraction inspection retained and excluded.
- Clean iOS demo build and retained Android APK provenance: verified in candidate manifest.
- Docs/output: passed; 172 help pages, 16 corpus/documentation tests, fresh empty test home, public compatibility terms, and doctor text/JSON ownership disclosure.
- Android runner smoke: running. The first three attempts stopped on harness setup; attempt 4 invoked stock crash incorrectly via direct runner. Those remain excluded with raw captures; reviewed corrections bind the versioned driver home and invoke the CLI for Android header-env conversion. Attempt 5 is governing if it completes all checks.
- CLI lifecycle: initial iOS startup interruption passed. Android exited 130 with correct emulator notice; helper mistakenly expected simulator. Scoped harness correction is under independent review; final rerun pending.
- MCP, final force teardown and exact owned cleanup: pending.

Owned simulator `B718468C-771F-47BC-9CD8-A1143D540AC5` (`smoke4-ios`, iOS26.0) and AVD `smoke4-android` (`emulator-5580`, emulator PID28028) remain active. Owner devices must remain untouched. Task9 remains gated until every bounded criterion and cleanup passes.
