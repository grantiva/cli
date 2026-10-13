# Android B3-L07 high-load review

**Verdict: PASS.** Reviewed current-round evidence at
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L07-high-load-ten-rerun2`
against the literal matrix row and runner `fd9d8e8`.

- Ten exact `02-favorite.yaml` commands use `--snapshot full`, exit 0, and
  report passed. Load immediately before every run is at least 8 (8.31 through
  44.78); after-run samples remain at least 12.92.
- Each flow uses the corrected distinct `Remove from favorites` action, then
  proves Lake Tahoe absent and the empty-state label visible. Thus all ten
  validate the revealed swipe action rather than relying on exit status.
- All ten runner logs contain exactly one held element drag:
  `(246,500) -> (0,500) over 300 ms`. Every matching client log preserves the
  single unredacted W3C `/actions` body beginning at `(246,500)`, moving to
  `(0,500)`, holding at the endpoint, and lifting. No retained runner/client
  log contains `input swipe` for the element gesture.
- Full before/after artifacts exist in every run. The load generator's owned
  PID inventory is retained and `load/still-alive.txt` is empty after cleanup.
- Exact source tests close the semantic clauses:
  `pkg/driver/uiautomator2/deterministic_gestures_test.go:451-490` asserts one
  pointer sequence, explicit default/custom duration, `(246,500)->(0,500)`,
  stationary 250 ms endpoint hold, and no shell command;
  `pkg/core/gesture_test.go:384-390` independently pins the same geometry.

The evidence therefore satisfies outcome, repetition, generated-load,
full-snapshot, route, unredacted-coordinate, distinct-label, source-test, and
cleanup requirements without qualification.
