# Task 9 AND-111 compile collector fix round 1

This correction addresses all four findings in `task9-and111-compile-review.md`. The review was read in full before editing. No live collector, source command, build, device, or network operation was run.

## Preserved reviewed inputs

- `task9_and111_compile.reviewed.py`: `7938955d92548212b47b98b9926500ee9b53f26fd8894e5dd0e2293ab5a8c769`
- `task9-and111-compile-preparation-reviewed.md`: `ca0731ec10cf3d8a208f73fad9316973af9ce9d8a235599a2bde8ddcdd618718`
- `task9_and111_compile_fixtures.reviewed.py` preserves the original three-check fixture file.

## Finding dispositions

1. **“ordinary Gradle project-cache output is incorrectly rejected”**: `.gradle/` is now an allowed generated root, alongside `app/build/` and `build/`. The fixture creates `.gradle/state.bin`, accepts it with the APK, then retains the unexpected sibling negative control.
2. **“frozen runner identity omits its actual symlink and candidate binary hash”**: the runner-home proof is now a non-following manifest containing path, entry kind, mode, regular-file hash/size, and symlink target. `candidate.runner.installed.path` is hashed against the candidate before and after. Fixtures retarget a symlink and reject a preexisting installed-runner mismatch.
3. **“fresh scratch/output checks do not all precede compilation”**: output validation occurs before directory creation and rejects descendants of the scratch project, source repos, runner home, CLI, bundle, APK, app, and installed runner. Preflight rejects generated scratch files, symlinks, and special entries before command-start or compilation. Fixtures cover protected descendants, preexisting output, and an unexpected link.
4. **“compile failure prevents required after-state evidence”**: the one compile call records and returns nonzero/timeout results. Postflight then attempts the after snapshot, source proofs, and transition checks. Any compile or later failure writes an exclusive `terminal-nonpass.json` with the compile result, ordered failures, and immutable first failure; it cannot write acceptance. Fixtures exercise nonzero and timeout subprocesses and confirm two postflight snapshot attempts.

The literal compile argv remains exactly `[CLI, "build", "build"]`. Candidate/input schemas and frozen source/artifact inputs were not changed.

## Verification

Exact command:

```text
python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task9_and111_compile_fixtures.py
```

Exact output:

```text
.......
----------------------------------------------------------------------
Ran 7 tests in 0.107s

OK
```

Syntax verification:

```text
python3 -m py_compile .superpowers/sdd/2026-10-13-round4-fix-wave/task9_and111_compile.py .superpowers/sdd/2026-10-13-round4-fix-wave/task9_and111_compile_fixtures.py
```

Exit was zero with no output.

## Fixed artifacts

- `task9_and111_compile.py`: `d1cdc4073e5a26a57d63d246b8840fc655b6d670b4f0ea61fcd920138ac588c9`
- `task9_and111_compile_fixtures.py`: `3e0c91b6f5d9760dea75bad8648c0d6358023d6dc931eb66b767baa64f8d8721`
- `task9-and111-compile-fix1-helper.diff`: `bcab4e33a7d55f45053b4a2fa7277c93736a9ee76e5e5283a95a68f8c77f84a4`
- `task9-and111-compile-fix1-fixtures.diff`: `87a30a89f1130e6da224bbaef943f3a2cc63643d80081b8cb302638b890da40c`

The helper remains preparation-only and has not been run.
