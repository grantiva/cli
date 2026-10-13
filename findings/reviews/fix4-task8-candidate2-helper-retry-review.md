# Task 8 candidate 2 helper retry review

Scope: final `task8-candidate2-android-focus-fix-report.md`, combined diff, corrected SDD copies of `android_runner_smoke.py`, `lifecycle_smoke.py`, `mcp_smoke.py`, and `candidate2_phase.py`. This was a bounded static review. No live command, device operation, build, test phase, or durable-helper mutation was performed.

## Verdicts

- **Specification compliance: APPROVED.** The four corrections address the observed controller failures without weakening product assertions, isolate a full Android retry from first-attempt artifacts, and preserve frozen candidate/ownership binding.
- **Code quality: APPROVED.** The initial durable-path defect was corrected in the final revision. The controller now resolves all promoted helpers from the flat durable helper directory, and the fixture loop no longer shadows the frozen CLI source-root variable. No remaining blocking issue was found.

Approval applies to final controller SHA-256 `823c56714ffda2e869ab6fdd82a5ae013febe6bbe3f2f4c42f5a365d347f127a`, report SHA-256 `87e54196dd144ccbc5564790e7ef537459eb0fe235717e53f2c229a88e1067dc`, and diff SHA-256 `5d6693fed8e4cc3658c412d4940734ed4c5754862e5e94131fb34794898c6e17`.

## Reviewed corrections

### Android focus

The helper changes only `adb -s <serial> shell dumpsys window windows` to the complete `adb -s <serial> shell dumpsys window` surface. It retains the exact `mCurrentFocus.*com.android.settings` predicate, immediate exact-package `pidof` absence, Settings hierarchy presence, Landmarks hierarchy absence, literal clear-state/bare-stop/not-visible flow inspection, passed `stopApp`, and intentional-stop/non-crash checks. This fixes the diagnosed output-surface omission rather than accepting a weaker Settings-window occurrence.

### Fresh output and fixture isolation

`--output` is optional and preserves the original per-phase default when absent; when supplied it resolves and exclusively creates a fresh path. The Android retry creates its input tree beneath that fresh output and reads only the frozen 13-row fixture manifest. Every source must resolve beneath the source input root, must not be a PNG, and must match the manifest SHA-256 before copy. Relative layout is retained, every destination hash is rechecked, the exact mapping is recorded, and the completed tree is asserted PNG-free.

All mutable Android input arguments point into the copied tree: runner inputs, optional inputs, crash flow, and healthy flow. The cycle fixture remains the explicitly separate scratch cycle project as before. The retry therefore cannot overwrite the twelve PNGs generated beside shared first-attempt YAML files. `source_fixture` also leaves the existing CLI `source` binding intact for identity and other phase construction.

### Lifecycle platform and report snapshot

Both ambiguous iOS command families now pass explicit `--platform ios`: all three log-cleanup cases and all three cycle-control forms. No expected exit, diagnostic, timing, report, child-process, or cleanup assertion changes.

`copy_report_snapshot` excludes only names ending in `.tmp`. A direct `FileNotFoundError` is tolerated only when it is `ENOENT` for a `.tmp` path; aggregated `shutil.Error` is tolerated only when every entry is a disappearing `.tmp` with the equivalent missing-file reason. Stable-file disappearance, mixed transient/stable failures, permission errors, and all other copy errors are re-raised. Session-file polling remains a separately scoped absence case. The change covers the observed atomic `report.json.tmp` race without hiding stable report failures.

### MCP decoded quote

The request label remains the semantic value `Mount "Denali"`, so JSON serialization still escapes its embedded quotes on the wire. Only the decoded reply prefix changes to `Tapped on "Mount "Denali""`, matching `Client.text()` and the retained successful response. The helper still requires a good tool result before prefix matching and preserves the complete selector sequence, identifier/placeholder annotations, application-root exclusion, missing-selector failure, and later transport checks.

### Durable execution paths

The final controller uses `h/'android_runner_smoke.py'`, `h/'lifecycle_smoke.py'`, `h/'mcp_smoke.py'`, and the existing durable joint helper, where `h` is the flat `findings/tools/round4-smoke-candidate2` directory. After the reviewed SDD files are copied flat into that directory, the invoked paths are durable and independent of the SDD preparation tree. The earlier nonexistent `task-8-candidate2-harness/` lookup is absent.

Before execution, the controller and all three corrected helpers must be copied byte-for-byte from these reviewed SDD versions into their named flat durable paths. Fresh retry outputs should retain `executed-helper.py`, invocation metadata, and fixture-copy evidence so the executed hashes remain reviewable. This is an execution binding, not an additional code change or validation framework.
