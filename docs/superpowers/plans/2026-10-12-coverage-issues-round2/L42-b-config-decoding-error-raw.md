# A malformed native screens step is reported as a raw Swift `DecodingError` dump instead of a config error that names the file, line and accepted forms

Severity: ux
Component: cli
Platforms: both (shared config decoder; observed on Android, 1 of 1; logical).
Rows: B-C08.2 [android]
Regresses/extends: new (K-series message hygiene; same family as K52/K73 raw errors). Split from L42-a, same cluster M36.
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
A config that does not decode fails with a message in the voice of `Sources/GrantivaCore/Errors` (plain, name the thing,
say what to do), e.g. `grantiva-android.yml:11: tap takes a label or {text: "…", exact: true}; unknown key "id".`
No `DecodingError.keyNotFound`, `CodingKeys(stringValue: …)` or "Debug description" in user output, and a single
`Error:` prefix without `Invalid argument:`.

## Actual
findings/evidence/cov2-android/B-C08.2/01.err:
```
Error: Invalid argument: grantiva-android.yml could not be parsed: DecodingError.keyNotFound: Key 'text' not found in keyed decoding container. Path: screens[0].path[2].tap. Debug description: No value associated with key CodingKeys(stringValue: "text", intValue: nil) ("text").
grantiva-android.yml:11: unknown key "id"
grantiva-android.yml:12: unknown key "id"
exit=1
```
The useful part (the line-numbered unknown-key warnings) comes after the dump.

## Repro
No device needed (parsing fails first). Any malformed label mapping shows it, independent of L42-a:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"; unset GRANTIVA_API_KEY
rm -rf /tmp/l42b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l42b && cd /tmp/l42b/android
cat > grantiva-android.yml <<'YAML'
platform: android
application_id: com.kylebrowning.landmarks
emulator: fix-l42b
screens:
  - name: Deep Links
    path:
      - tap: {txt: "Deep Links"}
  - name: Wait
    path:
      - wait: soon
YAML
grantiva diff capture --device emulator-5598 --no-build; echo exit=$?    # unused serial; parsing fails first
```
Expected: one config error per bad step, each with its line (`:7`, `:10`), naming the accepted forms; no Swift type
names.

## Evidence
- findings/evidence/cov2-android/B-C08.2/01.err, commands.txt

## Suspected cause
`Sources/GrantivaCore/Config/GrantivaConfig.swift` interpolates the raw error into the message:
- `:317` YAML parser failure: `"\(fileName) could not be parsed: \(error)"`;
- `:337` the same for a flow-format file that throws a non-`GrantivaError`;
- `:350` the native decode: `"\(fileName) could not be parsed: \(error)\(hints)"`, with the unknown-key warnings
  appended as hints.
All three use `GrantivaError.invalidArgument`, which adds the `Invalid argument:` label. `DecodingError` carries a
`codingPath` that maps onto the YAML node (the key validator already resolves line numbers from the node tree,
`ConfigKeyValidator.swift:8-35`).

## Acceptance criteria
- `keyNotFound`, `typeMismatch`, `valueNotFound` and `dataCorrupted` from the config decoder are rendered as
  `<file>:<line>: <path in config terms> …` with what the key accepts; Swift type names, `CodingKeys(...)` and
  "Debug description" never appear in output.
- Unknown-key warnings for the failing step are folded into that message (not printed after a dump).
- The message has one `Error:` prefix and no `Invalid argument:` (K46/K52 voice).
- Tests in GrantivaCoreTests/GrantivaConfigPlatformTests.swift: decoding the repro config throws a `GrantivaError` whose
  text contains `grantiva-android.yml:7`, `tap`, and does not contain `DecodingError`, `CodingKeys` or `Debug
  description`; same for the `wait: soon` type mismatch at `:10`.
