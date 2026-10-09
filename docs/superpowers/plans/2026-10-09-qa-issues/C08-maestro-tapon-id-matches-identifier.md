# Match Maestro tapOn id against the accessibility identifier, not label text

Severity: wrong-result
Platforms: cli, ios
Found by: CLI-F28 (matrix rows CLI-064)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`tapOn: {id: …}` taps the element with that accessibility identifier, as it does under `run --flow`. Source: README
§Maestro Compatibility (`tapOn` supported); Maestro semantics of `id`.

## Actual
In parsed mode the id becomes a text search:
```
    ✗ tapOn: text="clock" (18.0s)
      ╰─ Element not found: text='clock' (cause: context deadline exceeded: WDA error: unable to find an element using
         'predicate string', value '(label CONTAINS[c] 'clock' OR name CONTAINS[c] 'clock' OR value CONTAINS[c] 'clock')'
```
Under `--flow` the runner does `tapOn: id="clock"`. Triage re-run on Settings: `tapOn: {id: "General"}` generated
`tapOn: text="General"` and reported `Tap on "General"`. An id that is a substring of some label taps the wrong element.
`assertVisible`, `assertNotVisible`, `scrollUntilVisible` and `extendedWaitUntil` have the same `text ?? id` merge.

## Repro
1. Boot a simulator (`udid=$(grantiva simulator ensure --name "iPhone 17 Pro")`).
2. In an empty dir write `grantiva.yml`:
   ```
   appId: com.apple.Preferences
   ---
   - launchApp
   - tapOn:
       id: "General"
   - takeScreenshot: "after"
   ```
3. `grantiva run --no-build --simulator "$udid" --bundle-id com.apple.Preferences 2>&1 | grep tapOn`
   shows `tapOn: text="General"`. Compare `grantiva run --flow grantiva.yml ...`, which shows `tapOn: id="General"`.
   (fixtures/maestro/tapOn-id.yaml is the landmarks-demo version.)

## Evidence
- findings/evidence/cli/maestro/tapOn-id.parsed.log vs findings/evidence/cli/maestro/tapOn-id.flow.log

## Suspected cause
Sources/GrantivaCore/Config/MaestroFlowParser.swift:380-390 (`parseTapSelector`): `obj["text"] ?? obj["id"]` feeds
`tap:`; GrantivaConfig.Screen.Step (Sources/GrantivaCore/Config/GrantivaConfig.swift:28-50) has no id field, so
FlowGenerator can only emit a text selector. Same merge at :341 and in the assert/scrollUntilVisible branches.

## Acceptance criteria
- Re-running the repro, the generated flow contains `tapOn: id: "General"` (and the step label says id).
- Step gains an id-selector form (e.g. `tap: {id: X}`) carried through FlowGenerator for tap, assertVisible,
  assertNotVisible, scrollUntilVisible and extendedWaitUntil.
- GrantivaCoreTests: a MaestroFlowParser test asserts `tapOn: {id: X}` yields an id selector, and a FlowGeneratorTests
  case asserts it is emitted as `id:`.
