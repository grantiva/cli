# Accept the standard Maestro swipe, extendedWaitUntil, and waitForAnimationToEnd forms, and make README match unsupported-command handling

Severity: wrong-result
Platforms: cli, ios
Found by: CLI-F27, CLI-DOCS-F04 (matrix rows CLI-063, CLI-065, CLI-112)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
"Supported Maestro commands: `tapOn`, `inputText`, `assertVisible`, `assertNotVisible`, `swipe`, `scroll`, `runFlow`,
`extendedWaitUntil`, `waitForAnimationToEnd`, and `takeScreenshot`. Unsupported commands (scripting, permissions, etc.) are
silently skipped." Source: README §Maestro Compatibility (README.md:149).

## Actual
The standard forms `swipe: {direction: UP}`, `extendedWaitUntil: {visible: "Featured", timeout: 5000}` and bare
`- waitForAnimationToEnd` fail before any device work (they pass under `--flow`):
```
Error: Invalid argument: grantiva.yml could not be parsed: invalidArgument("Unsupported Maestro command \'swipe\' at <input>:4")
Error: Invalid argument: grantiva.yml could not be parsed: invalidArgument("Unsupported Maestro command \'extendedWaitUntil\' at <input>:4")
Error: Invalid argument: grantiva.yml could not be parsed: invalidArgument("Unsupported Maestro command \'waitForAnimationToEnd\' at <input>:4")
```
Unsupported commands are not skipped either; `- back` fails the whole file:
```
Error: Invalid argument: grantiva.yml could not be parsed: invalidArgument("Unsupported Maestro command \'back\' at <input>:5")
```
The message leaks the Swift enum (`invalidArgument("…")`) and says `<input>` instead of the file name.

## Repro
For each of `swipe`, `extendedWaitUntil`, `waitForAnimationToEnd`, `back` (fixtures/maestro/<cmd>.yaml on branch qa/cli):
```
mkdir -p /tmp/c07 && cd /tmp/c07 && cp <qa-cli>/fixtures/maestro/swipe.yaml grantiva.yml
grantiva run --no-build --simulator <udid>
```
No device work is needed to see the parse error. Fixtures target the landmarks-demo app (`com.kylebrowning.Landmarks`).

## Evidence
- findings/evidence/cli/maestro/swipe.parsed.log, extendedWaitUntil.parsed.log, waitForAnimationToEnd.parsed.log, back.parsed.log
- findings/evidence/cli/maestro/swipe.flow.log etc. (same files pass under `--flow`)

## Suspected cause
Sources/GrantivaCore/Config/MaestroFlowParser.swift:291-308 handles only `swipe: {start:, end:}`; :340-344 reads
`text`/`id` but Maestro's key is `visible` (a string or `{text:/id:}`); :231-238 has no bare `waitForAnimationToEnd` case.
`parse`/`loadDirectory` default to `allowUnsupportedCommands: false` (:27, :104). GrantivaConfig.swift:200 calls
`MaestroFlowParser.parse(contents)` without `sourceName` and interpolates the enum with `\(error)` (:202).

## Acceptance criteria
- Re-running the repro, the three standard forms parse and the run proceeds to the device.
- Decide one behavior for unsupported commands (skip with a stderr warning naming command and line, or reject) and make
  README.md:149 say exactly that; also list `doubleTapOn`, `longPressOn`, `scrollUntilVisible`, `launchApp`, `stopApp`,
  `killApp`, which the parser accepts.
- Errors read `grantiva.yml:4: unsupported Maestro command 'back'` (file name, no enum text).
- GrantivaCoreTests: a MaestroFlowParser test per form (`swipe: {direction: UP}` → swipe up, `extendedWaitUntil:
  {visible: "X"}` → assertVisible X, bare `waitForAnimationToEnd` → wait step) and one asserting the error message format.
