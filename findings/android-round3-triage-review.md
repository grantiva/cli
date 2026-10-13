# Android round-3 failure disposition audit

Scope: the 17 base-row failures in `cov3-android-results.md` plus side finding `AND3-OBS-01`. This is a read-only disposition audit. It does not change product code, matrix criteria, or verdicts.

| Finding | Disposition | Supporting evidence |
|---|---|---|
| B3-L57 | Product regression brief L64 | Current runtime allows `launchApp` to pass after FATAL. The ledger correctly qualifies the stale-read cause as suspected rather than proven. |
| B3-L15.2 | Product contract brief L65 | The live MCP script error says `'steps' array is required.` rather than the literal required wording. |
| MCP-078 | Expectation correction | The literal every-tool-isError rule conflicts with app-independent screenshot, swipe, and hierarchy behavior against system UI. The raw retains the mixed results and does not claim an app-liveness defect. |
| AND-127 | Product regression brief L68 | Detached readiness precedes the app foreground postcondition; isolated polling reproduces the system-UI window. |
| B2-K19 | Expectation correction / incomplete compound | Exact source intentionally makes verbose win over quiet, explaining that literal conflict. The ledger also discloses the unverified JSON/quiet and diff/CI forms. |
| AND-137 | Expectation correction | Byte equality across separate JSON runs is incompatible with measured step durations; quiet/verbose routing otherwise behaves correctly. |
| AND-138 | Expectation correction | Byte equality across separate capture JSON runs is incompatible with capture duration, measured duration, and timestamps; stream routing otherwise behaves correctly. |
| AND-022 | Fixture limitation / expectation correction | The prescribed demo release variant is deliberately debug-signed, so it cannot exercise an unsigned-release warning. The ledger does not attribute this to product behavior. |
| B2-K25 | Expectation correction | Android `ci run` is deliberately rejected as local-baselines-only before the paired-flag behavior requested by the compound criterion can occur. Exact install/run/capture controls remain preserved. |
| N3-03 | Product contract brief L69 | Starting-session JSON omits the required explicit `port: null` while text and PID reuse are correct. |
| B3-L55.2 | Accepted expectation correction | Runtime and source prove ready files are terminal-only; the literal active `ready.status=running` state cannot occur. |
| X-013 | Accepted expectation correction | Platform contracts intentionally use `bundleId` on iOS and `applicationId` plus `serial` on Android, conflicting with literal full-key equality. |
| N3-06 | Accepted expectation correction | All MP4s are exactly three seconds; `recordedMilliseconds` intentionally measures the pre-hold track end rather than final encoded duration. |
| B2-K103 | Accepted expectation correction | Public compatibility documentation intentionally retains 16 named snake_case aliases with equal camelCase twins, contrary to the literal no-underscore criterion. |
| B-C22.2 | Documentation regression brief L74 | ISO-8601 runtime/source behavior is correct, but the required public change note is absent. |
| B3-L20 | Product/path contract brief L75 | The subdirectory cycle chain resolves relative hops rather than normalizing every hop project-relative as prescribed. |
| B3-L49 | Product regression brief L77 | Bare Android `stopApp` reports success although the app remains onscreen and the following absence check fails. |
| AND3-OBS-01 | Product/CLI aggregation brief L79 | Runner overall status is passed for the optional missing tap, but CLI step reconstruction reports failure and exits 1 despite fast first lookups. |

## Audit result

All 18 findings have an evidence-backed disposition. Eight map to controller briefs L64, L65, L68, L69, L74, L75, L77, and L79. Ten are expectation/fixture corrections whose ledger text identifies the literal conflict and avoids presenting it as an unsupported product regression.

The controller's round-3 expectation-correction document must include MCP-078, B2-K19, AND-137, AND-138, AND-022, B2-K25, B3-L55.2, X-013, N3-06, and B2-K103 before final reporting. No correction file was present in the controller issue directory during this audit, so this review is the explicit handoff rather than a claim that those matrix edits already exist.
