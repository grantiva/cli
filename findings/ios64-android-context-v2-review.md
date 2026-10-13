# iOS attempt64 review and Android context-v2 investigation

## iOS attempt64

All four new grades are supported by exact fresh inputs.

- **IOS-060:** the first keep-alive run is proven live and owned on U1. The second exact same-UDID run exits 1 in 1.06 seconds; its error names the owner PID, runner PID, age, keep-alive state, exact force-teardown command, and alternate-device guidance. This is the required immediate ownership refusal.
- **IOS-086:** without a `runner start`, exact `runner dump-hierarchy --udid U1` exits 0 against the live keep-alive session and returns the current Landmarks detail XML. This is the documented fallback rather than a newly created runner session.
- **IOS-090:** both owned simulators are booted before and after. The config-selected capture names U1 and writes five plain filenames including `Deep Links.png`. U2's installed-app container path is byte-identical before/after, while output never selects U2. That supports the untouched-device clause without relying only on screenshots.
- **IOS-107:** one request contains the literal three-step array: tap `Favorites`, wait 1 second, then point tap `(200,400)`. The result reports the three steps in order and succeeds with the final Favorites hierarchy. On iOS the supplied coordinate values are points, satisfying the unit clause.

## Android detached context-v2

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/D239-X011-MCP076-context-resources-rerun2/`.

This is a timing-limited harness attempt, not evidence of a new product defect:

- Detached `runner start` exits 0 with a non-null UIAutomator2 port.
- The bounded `runner dump-hierarchy` control immediately succeeds and sees the Landmarks list, proving the driver/app are usable through the project session path.
- The following standalone `hierarchy` XML and JSON calls both return the documented retryable `runner session is starting` classification. Candidate docs explicitly say that while a discovered session is still starting, hierarchy surfaces say so and request a retry (`docs/dump-hierarchy.md:57`; `docs/android.md:200-203`).
- `HierarchyCommand` is primarily documented for the global session published by `run --keep-alive` (`HierarchyCommand.swift:5-27`; `docs/dump-hierarchy.md:7-25`; `docs/android.md:138-147`). Its lookup goes through `KeepAliveSessionStore`, whereas `runner dump-hierarchy` can use the project `.grantiva/session.json`. Thus a successful project-session dump does not prove that the independently published global record has completed its starting-to-ready transition at that same instant.

The v2 helper performs no retry after either standalone starting response, so it cannot distinguish the known publication/readiness window from a persistent detached-session lookup defect. Preserve the exit-8 attempt as diagnostic evidence and exclude it from X-011/D2-39/MCP-076 grading. The worker's keep-alive v3 uses the command's primary documented contract and is the correct exact input for X-011/B2-K56. No new brief is supported from v2.

