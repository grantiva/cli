# Stable manual emulator fixture — fix round 2 review package

Input review: `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/.superpowers/sdd/2026-10-13-campaign-completion-plan/android-fixture-fix1-review.md`.

Artifacts:

- revised helper: `stable-manual-emulator.py`, SHA-256 `6d4a99694878ccbe9b5a3790b0bfc869a0b961724128c8a3313800d9254a1397`
- focused fake scenarios: `test-stable-manual-emulator-fix2.py`, SHA-256 `d7d3783d297e5d1b484714cabc1fe2a01cff83f76ec58a5ae6c46464a1ae2d20`
- regression output: `stable-manual-emulator-fix2-regression-tests-rerun2.txt`, SHA-256 `4f8737a9f17b4e4b7c5ba769f32694354a69793ec0aa8ee7eb49e43dc4c040fd`
- focused output: `stable-manual-emulator-fix2-focused-tests-rerun2.txt`, SHA-256 `2678e449c9fa27353bc3180ccd8760ef58560b2d3be0ce2fac9e74764b9ac6bf`
- exact fix1 helper snapshot: `stable-manual-emulator-fix1.py`, SHA-256 `bd919f9a8d5250ebe394bf9d1c8563842e288fc28ed36e5f62524f9481b5f1c6`

Acceptance evidence:

1. A fake adb nonzero/offline observation is retained, followed by an all-zero ready observation within the same launch deadline.
2. A fake same-PID/start/group/session wrapper identity transitions to exact qemu/AVD/port identity; only the latter becomes durable ownership.
3. A fake probe emits both streams and hangs. Lossless base64 bytes survive through parseable launch and verification terminal JSON.

The helper adds no cleanup or signal behavior. The candidate is retired and this package grants no live or coverage authorization.
