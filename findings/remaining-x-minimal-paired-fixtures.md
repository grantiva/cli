# Minimal paired fixtures for remaining X rows

This turns `remaining-x-crossplatform-gapmap.md` into bounded worker handoffs. Each pair must use the same logical input and preserve commands, split stdout/stderr, exits, and JSON. Existing exact joins should be used before running a fixture.

| ID | Minimal paired fixture or exact retained join |
|---|---|
| X-004 | **One small paired run:** `run --no-build --flow 18-long-wait.yaml --ready-file interrupted.json`, no `--report-dir` on either platform; send SIGINT only after the flow is active. Compare top-level and flow keys/status. This closes only the mismatched interrupted leg; reuse existing pass/fail. |
| X-007 | On each platform, same five-screen config: `diff capture --no-build` then identical command with `--json`, preserving text/JSON and captures. Compare screen/step schema; Android alone adds `emulator`; text uses Simulator versus Emulator. |
| X-010 | iOS only if attempt51 lacks exact input: `record --duration 3 --frames-at 0,1000 --json` on the idle owned device. Join existing Android `X-010/`; compare frame fields and documented compatibility/device additions. |
| X-011 | Establish the Landmarks **list** on each live keep-alive session, then capture `hierarchy` XML and `hierarchy --format json` without further navigation. Preserve a visible list label proving state. Compare roots/tree conventions and numeric point-versus-dp frames. |
| X-013 | One detached session per platform: start text, stop text; repeat start/stop with `--json`; finally no-session stop JSON. Compare shared messages/key sets and only the documented simulator/emulator ID/name substitutions. |
| X-014 | **No rerun.** Reuse iOS attempt31 plus Android `X-cross-platform-audit/` and `secondary-shutdown-contracts-exact-rerun3/`; accepted review already closes fresh and reused plain+JSON semantics. |
| X-015 | Android only: while exactly one row-owned AVD/session exists, preserve `emulator sessions --json`. Join iOS `cov3-ios/IOS-010/sessions-json.out`; compare ownership/state/name/ID fields and parse both timestamps as ISO-8601. |
| X-017 | Pair exact `doctor --platform ios` and `doctor --platform android`, text and `--json`, without quiet. Compare every JSON check record's key set and status vocabulary. Reuse iOS attempt43 if its command matches exactly. |
| X-018 | While an owned session is live, issue the same second-run flow on each platform. Preserve fast refusal, owner-survival hierarchy, and full error text; compare structure and platform-specific teardown/unique-device guidance. |
| X-019 | Android only: exact-negative flow with stderr preserved. Join iOS attempt10; compare failed-step/cause structure and the single hierarchy/MCP remediation line. |
| X-020 | Android only: same-project live keep-alive then `grantiva_context`. Join iOS attempt4; compare Config/device/toolchain/Runner Session sections and all active-session fields. |
| X-021 | One MCP process per platform on equivalent live app state: successful tap, swipe, focused type, and a11y_tree, with one response file per operation. Compare result content/tree shapes; do not mix failures into this success row. |
| X-022 | Per platform, capture once without a session and once through a proven-ready live session, plus CLI `diff capture --no-build --json` for each target. Compare MCP to same-platform CLI first, then shared cross-platform shape and Android's `emulator` addition. iOS attempt22+56 may be reused. |
| X-024 | Same flow 08 with `--logs` on each platform. Preserve interleaved stdout/stderr from launch through completion and extract `[log]` lines with adjacent step lines. Compare prefix and interleaving form, not log contents. |

Rows X-014 and the iOS halves of X-015/X-019/X-020 need no new device work. X-004 needs only the interrupted leg. Workers should inspect existing commands before scheduling any other fixture; exact matches can replace the proposed run.
