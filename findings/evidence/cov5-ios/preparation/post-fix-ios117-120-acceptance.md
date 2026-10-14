# Bounded post-fix iOS 117–120 acceptance

Status: read-only preparation; no command in this recipe has run. Use only after root activates a new exclusive iOS window and supplies a candidate manifest/binary binding.

Targets remain the exact campaign-owned primaries: iOS 26 `532523A7-30B3-4048-A538-4F3DB2EFB807` and iOS 27 `EED50B5C-119B-4982-A495-4521CAE8494F`. Use session `cov5-ios`, both runner-home variables `/private/tmp/grantiva-cov5-ios-runner-home`, and unset `GRANTIVA_API_KEY`.

1. Before execution, bind the replacement candidate identity and capture both primary states plus frozen-app hashes. Do not build or replace the demo app.
2. Repeat the exact IOS-117 stock command on primary26. It must exit 0, capture all five configured screens, run 12/12 flows, and log the cached iOS 26 agent. Preserve the old candidate4 failure beside the new candidate evidence.
3. Repeat the exact IOS-120 `diff capture --no-build` command on primary26. It must exit 0 with 5/5 screens. Inspect the Lakes and Detail images; Detail must contain Golden Gate Bridge / Plan Visit rather than Lakes content.
4. Repeat the corresponding stock and diff commands on primary27 to guard the previously passing runtime: 5/5 screens and 12/12 flows must remain passing.
5. If the replacement runner trace already exposes the matched accessibility element ID, retain the before/after selector lines and hierarchy excerpt around the second `Landmarks` tap. Do not add a third diagnostic run or a general tracing harness solely to obtain an ID.
6. Verify both exact primaries remain Booted with frozen-app hashes matching provision evidence, no extras or owned workers remain, and protected devices were unchanged.

The candidate4 trace directly proves that the second `Landmarks` tap reports success while Lakes/Crater Lake content remains and `Golden Gate Bridge` is absent. Matching the selected tab/back-label element is an inference unless an existing replacement trace exposes the matched element identity.
