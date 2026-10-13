# Task 9 source-window controller review fix round 2

Status: **PREPARATION ONLY; NOT EXECUTED.** Fix round 2 changes only the two residual P2 cases in `task9-source-window-controller-fix1-review.md`. Fix-1 helper SHA-256 `b7b176286a4e9ddcf5041980964e82bf99ef71f955547ed3ecf1906af2e63b06`, fixtures SHA-256 `70eb0a4917d782f76a3ac75aa85ba8b085377da5a0e1b10dfae670f5c27349f1`, and scoped diff SHA-256 `e43b3abc8046a23a0f92bff1190d4c5254404b8109b1ba221eef16bc760d09cb` remain preserved inputs.

## Residual findings fixed

**P2 — home root objects can still be mistaken for empty homes.** `path_entries` now performs a non-following root check with `os.path.lexists`. It distinguishes `absent`, real `directory`, `file`, `symlink`, and `other` root kinds. Swift postflight permits only an absent root or a real directory with zero entries. A regular file, any symlink root including a dangling symlink, another root type, or any directory entry produces a durable reason and closes the window. Go cache population remains unaffected because only the two Swift home variables receive this postcondition.

**P2 — deletion of a tracked source file still loses drift postflight.** `observe_repo` now records missing, invalid, and unreadable tracked entries in `trackedEntryIssues` and places stable sentinel bytes in the observed tree digest. It returns the captured HEAD, status, count, digest, and structured issues instead of raising for those entries. `proof_failures` turns any issue into `invalid-tracked-entries`; the existing postflight writes that full observation and `terminal-failure.json`, stops selection, and emits the closed manifest. Valid readable tracked files, including in-repository symlink targets accepted by the previous implementation, retain the prior hashing behavior.

## Verification

Exact allowed command:

```text
python3 -m py_compile .superpowers/sdd/2026-10-13-round4-fix-wave/task9_source_window.py .superpowers/sdd/2026-10-13-round4-fix-wave/task9_source_window_fixtures.py && python3 .superpowers/sdd/2026-10-13-round4-fix-wave/task9_source_window_fixtures.py
```

Exact output:

```text
............
----------------------------------------------------------------------
Ran 12 tests in 0.843s

OK
```

The actual-control fake integration now makes the fake zero-exit Swift process both populate its runner home and delete `tracked.txt` from the fake CLI checkout. The resulting real controller artifacts contain `nonempty-GRANTIVA_RUNNER_HOME`, `invalid-tracked-entries`, and `trackedEntryIssues: [{"issue":"missing","path":"tracked.txt"}]`, with `CLOSED_NONPASS_UNREVIEWED`. A second bounded fake-subprocess fixture creates a regular-file root and a dangling-symlink root and verifies both yield `invalid-root-GRANTIVA_RUNNER_HOME`.

No candidate source, test, build, Go inventory, device, live, network, product file, or durable helper was touched. Task 9 remains gated. Root owns independent re-review.
