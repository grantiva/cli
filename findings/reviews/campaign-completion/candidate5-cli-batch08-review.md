# Candidate 5 CLI batch 08 review

Scope: flattened direct ordinals 176–200 only, checked against the canonical rows and evidence referenced by the current ledger.

## Verdict

- **Spec: NOT APPROVED as proposed**
- **Evidence quality: NOT APPROVED as proposed**
- **Supported: 23 PASS**
- **Evidence gaps: 2 (`B-A10.4`, `B-A12.3`)**

The proposed 25-PASS batch overstates two source-test rows.

`B-A10.4-run-1/source-inspection.stdout` contains only five class/extension declaration matches for `SimulatorLeaseTests`, `InstallCommandTests`, and `TableFormatterTests`. It does not retain the required assertions that the Android lease message names `grantiva emulator`, Android install JSON has the specified keys, or a failed Android build table omits `Scheme:`. The command searched only the three class names. This establishes that the suites exist, not that any of the three literal tests exist or pass.

`B-A12.3-run-1/source-inspection.stdout` contains the `DoctorTests` class declaration and production `Git Repository` status strings. It does not retain tests for nested `root/android` under an ancestor `.git` directory and for the no-ancestor warning. The adjacent `B-A12.1` and `B-A12.2` runtime captures support product behavior and implementation, but they do not satisfy this row's explicit two-test clause.

The other 23 PASS rows are supported by their fresh candidate evidence. In particular:

- `MCP-077` preserves its first missing-capture assessment and uses six fresh adjacent protocol captures. Each transcript contains a tool result with `isError`, no JSON-RPC error, and a following response; the session tools stop at the required no-session boundary without live target action.
- `B-C01.4` preserves its first missing-capture assessment. The adjacent current-source search identifies the nil-returning `Bundle(url:)` lookup path and related missing-bundle tests, rather than transferring an earlier runtime grade.
- `B-C01.1` directly exits 1 with a `GrantivaError` naming the missing adjacent resource bundle and retains isolated-home state evidence. `B-C01.3` retains the exact lock-preservation and throwing-extract test lines.
- The remaining source-only rows retain matches for their required implementation and test behavior, while `B-A12.1`/`.2` retain current-candidate doctor output showing repository detection from the nested repro.

Candidate identity records for the corrected captures bind manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`; the shared identity record hash is `eab8f2b9c63ee0526e92f967e5c9b3e4e116df607069bedf0e4d00635f92e047`. The proposed batch verdict SHA-256 is `022ea1a8b3d64f88843dd3a9cb518fa63eb7751314363c724edf397f9ba5817f`.

No rerun is needed to assess the retained evidence. `B-A10.4` and `B-A12.3` need an exact current-candidate source/test join that proves their named assertions before they can be graded PASS.
