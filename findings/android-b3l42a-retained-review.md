# Android B3-L42-a retained-evidence review

## Verdict: PARTIAL — one exact negative input remains

The positive and documentation clauses are fully supported:

- `B2-K24-exact-rerun1` runs `diff capture --no-build` both with inferred Android and explicit `--platform android`. Its native screens config contains `tap: {id: "clock"}` and `assert_visible: {id: "clock"}`. Both runs exit successfully, report both id actions passed, and preserve the Caching Maestro PNG. No unknown-key warning is emitted for `id`.
- Its exact-head `GrantivaConfigPlatformTests-native-id.txt`, `FlowGeneratorTests-native-id.txt`, and `FlowStagingTests-K24.txt` show parsing into by-id flags and generated runner YAML containing `tapOn.id` and `assertVisible.id`; the retained CI log records those semantic tests passing.
- `B2-K109-BC08-config-forms-rerun1/happy` adds successful live id forms and a captured screen, corroborating the selector pipeline.
- `B2-K24-exact-rerun1/source/README-native-and-maestro-config.txt` documents `{id: "clock"}` in the screens selector section and explains that a selector mapping names `text` or `id`.

I did not find the matrix's exact negative scratch step containing both `{id, text}` in either retained runtime set. Nor is there a retained command result proving that this specific config is rejected with an error naming the step. The smallest complement is device-free: parse or invoke `diff capture` with one scratch native screen step such as `tap: {id: "clock", text: "Clock"}` and retain the nonzero error that names the offending step and the mutually exclusive keys. Until that exists, B3-L42-a [android] should remain ungraded/partial rather than inheriting the positive K24/K109 pass.

Evidence roots:

- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K24-exact-rerun1/`
- `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K109-BC08-config-forms-rerun1/`
