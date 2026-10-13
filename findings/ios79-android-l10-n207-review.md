# iOS attempt 79 and Android L10/N2-07 review

Scoped independent review against the round-3 matrix, candidate CLI `8f2cff676b3c12e951478920fa20e600cdca4e29`, and runner `fd9d8e8d1cb109eda6116f4221da10257b9838e3`.

## B3-L20 [ios]: product formatting defect confirmed

Attempt 79 is terminal and immutable (`summary.json`, four exit files, and `all-files.sha256`). All four cases exit 1 in 1.5–2.1 seconds, so cycle detection itself is bounded and correct. Root flow output is exactly `a.yaml -> b.yaml -> a.yaml -> b.yaml`; both screens forms correctly begin `grantiva.yml -> a.yaml -> b.yaml -> a.yaml`.

The required subdirectory case fails: it prints `flows/a.yaml -> ../shared/b.yaml -> ../flows/a.yaml -> ../shared/b.yaml`, while B3-L20 and the accepted L20 brief require every hop relative to the project working directory: `flows/a.yaml -> shared/b.yaml -> flows/a.yaml -> shared/b.yaml`. The operands are valid and the fixture is exact. This is not a matrix mismatch.

The defect is in the CLI output map, not runner cycle detection. `FlowReferenceResolver.reachableFlowDisplayMap` correctly maps each canonical absolute reachable file to its project-relative path. But `RunnerSession.runFlowFiles` subsequently merges `subFlowPathMap` with `{ _, written in written }`. That later map stores each nested operand exactly as written (`../shared/b.yaml`, `../flows/a.yaml`) and overwrites the canonical project-relative values. `OutputRewriter` then intentionally emits those overwritten values. Existing `testEveryReachableSubFlowMapsToItsProjectRelativePath` tests the good reachable map in isolation and never exercises the destructive merge. L75 tracks the confirmed defect.

## B3-L10 and S2-03 [android]: supported

The rerun uses the same explicit report directory for plain and quiet and preserves separate archived outputs/reports after each command. Plain, quiet, and JSON each exit 1; the bad-device pre-flow control also exits 1. Plain and quiet stdout are byte-identical and include all five successful screen blocks, the failed flow, the marked failing step and its message, `Screens: 5 total, 5 captured, 0 failed`, and `Flows: 1 total, 0 passed, 1 failed`. Quiet removes narration from stderr while retaining the result. JSON preserves the failed structured result. The bad-device refusal emits no stdout summary. This fully supports B3-L10 and the Android half of S2-03.

## N2-07 [android]: supported

The read-only audit hashes exact current emulator ensure, diff capture/compare/approve, and runner start/stop documents. Every documented alias that occurs has an equal camelCase twin, lifecycle start/stop have equal `applicationId`/`bundle_id` and `serial`/`udid`, and no undocumented snake_case key occurs. Emulator ensure has no snake_case key because none of the README's legacy ensure aliases apply to that Android result shape. Exact-head README, `LegacyJSONKeys`, platform twins, and semantic casing tests are cited and inspected. The platform-half pass is supported.
