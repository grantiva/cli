# iOS round-3 coverage completion

The iOS matrix is complete: all 478 base rows have a verdict and retained evidence.

- Pass: 447
- Fail: 21
- Blocked: 10
- Missing base rows: 0
- Duplicate or excess base rows: 0
- Missing evidence paths: 0
- Unvalidated relative evidence paths: 0

The ledger also retains 39 iOS 27 repeat passes, six handed CLI passes, and the separate `IOS3-OBS-01` failure observation. These are excluded from the 478-row base counts.

The final closure batch established:

- `B-C01.2 [ios]`: concurrent runner re-extraction preserves the live lease, marker locks, reports, and xcconfigs while exact slow flow 11 completes.
- `IOS-095`: deterministic color-only PNG pairs cross `perceptual_threshold: 5.0` at measured distances 3.437 (pass) and 5.190 (fail).
- `B2-K106 [ios]`: force teardown removes both claimed temp directories after a killed non-keep-alive run, joined with the retained keep-alive, preserved-report, and live-owner controls.
- `B-I09.1/.2 [ios]`: force teardown keeps a dead-owner capacity record when the same session remains live on another owned device, with exact source tests covering stale and pending clearing.
- `B3-L12 [ios]`: runner death and interrupt cleanup remove owned session files; force teardown removes a sidecarless dead runner file while a live other-device runner remains usable.

Validation command:

```text
python3 /Users/kyle/Developer/grantiva-cli/.worktrees/regression/.superpowers/sdd/2026-10-13-round3-coverage-pass/audit_coverage.py ios
```

The final audit reports `recorded_base_ids: 478`, `pass: 447`, `fail: 21`, `blocked: 10`, and empty missing/duplicate/evidence-error collections.
