# CLI-004 cov5 clause assessment

Verdict: **pass**.

Current evidence was freshly executed against candidate4 manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; each command has adjacent identity and exit capture. The following observations are from this directory’s current stdout/stderr and command records:
- `help` exits 0 and `cmp-help` exits 0 against canonical `findings/help/run.txt`.
- Frozen candidate README lines 76–99 and `docs/android.md` lines 54–55 were captured from `/Users/kyle/Developer/grantiva-cli/.worktrees/release-round4-candidate3`; their named flags occur in the canonical help page.
- The help output contains none of `--auto-accept-alerts`, `--no-auto-accept-alerts`, or `--wait-for-idle-timeout`.
- Passing `--wait-for-idle-timeout 5` exits 64, writes the unknown-option error plus Usage/help hint to stderr, and writes no stdout.

All commands are help, source reads, or argument parsing before project/device resolution.
