# Candidate 4 CLI first-50 evidence review

Verdict: **APPROVED** for the first 50 direct rows currently listed in `cov5-cli/findings/cov5-cli-results.md`. I found no material unsupported pass in this bounded set.

Reviewed rows: CLI-001–010, CLI-123–125, CLI-011–017, CLI-019–021, CLI-126, CLI-023–026, CLI-030, CLI-032–035, CLI-128, CLI-036–043, CLI-028, CLI-127, CLI-038–039, CLI-044–046, CLI-027, CLI-029, and CLI-031 (50 total, in results-file order).

The review compared each row to its literal frozen-matrix clause, read every row verdict, checked the cited raw command records and streams, and verified all adjacent identity records bind candidate manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`. Across the 50 cited evidence directories, every command has raw stdout/stderr plus argv, cwd, exit, timeout, and process-group capture except the separately documented CLI-031 root-ruling directory, which points to its retained candidate-bound attempts. No identity file reports a candidate or artifact mismatch, and no cited command timed out or left its capture process group alive.

CLI-023's original unsupported verdict is not used. The results link now points to `CLI-023-rerun-2`, where fresh candidate-bound `doctor` output contains iOS/Xcode required checks and no Android required checks, while `init` identifies the Landmarks schemes and creates `grantiva.yml`. Those two captures support resolution of the Xcode-project-only fixture to iOS.

The parsing-only rulings for CLI-027, CLI-029, and CLI-046 are supported as scoped. Each command uses the proven-absent UUID `00000000-0000-0000-0000-000000000527` with `--no-build`, and reaches only exact target-resolution failure after accepting the relevant flow or action syntax. Their adjacent simulator inventories do not contain that UUID. This evidence supports parsing and discovery without claiming an application build or successful device run.

CLI-031 is supported under the controller's stated narrow ruling and preserves its scheduling deviation. The retained Android doctor/run captures select `grantiva-android.yml`; the iOS environment doctor selects `grantiva.yml`, and its run reaches `xcodebuild` before rejecting the deliberately incomplete project. The pass establishes config selection only and does not claim a successful build.

CLI-003's help regeneration reports `total=172 identical=172 different=0` against the frozen campaign corpus, with all pages exiting zero and containing the required headings. The remaining rows' raw outputs support their required exact text, JSON validity and stream placement, help equivalence, precedence, or pre-device validation clauses. Supplemental source-path mapping is outside this bounded first-50 review and was not used to manufacture a pass.

Material gaps: **none found**.
