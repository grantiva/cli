# Android B3-L58 review

## Verdict: PASS

`B3-L58-first-tap-parent-rerun1` satisfies every re-baselined clause:

- Exact `.maestro/03-edit.yaml` passes three of three, with the full edit/type/save postcondition and retained reports.
- In all three runs, the first request for `Deep Links` is the plain `new UiSelector().text("Deep Links")` query. There are no preceding clickable-only misses.
- The decoder correctly measures runner-side dispatch overhead from the step/search timestamp to the first client request after subtracting that request's own duration. Values are 0.354, 0.383, and 0.382 ms for the three required runs (0.342 ms in the scratch corroboration), far below 300 ms. It does not mistake the app/query latency for runner overhead.
- The scratch flow's unique `Name` text is queried plainly, its clickable attribute is read, and page source follows so the non-clickable match can resolve to its clickable parent. The tap lands: text input succeeds, Done succeeds, `Golden Gate Bridge Renamed` is visible, and the final screenshot is retained.
- Total first-tap times are recorded (843–946 ms for the three edit runs) without applying a withdrawn wall-clock target.

Runner candidate `fd9d8e8` at `pkg/driver/uiautomator2/driver.go:558-690` implements the observed plain-query-first and clickable-parent fallback, with exact retained tests including the non-clickable text/clickable-container case. The runtime logs demonstrate that path on the required fixture rather than relying on source alone.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L58-first-tap-parent-rerun1/`.
