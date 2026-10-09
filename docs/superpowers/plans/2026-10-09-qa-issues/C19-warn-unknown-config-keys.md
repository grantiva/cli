# Warn about unknown keys in grantiva.yml

Severity: ux
Platforms: cli, ios, android
Found by: CLI-F09 (matrix rows CLI-039)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
A misspelled or unknown key is rejected or warned about, naming the key and line. Source: QA spec §2 and matrix CLI-039
(docs/superpowers/plans/2026-10-09-qa-feature-matrix.md).

## Actual
`schem:` and `screen:` are dropped silently; the run fails with an unrelated message:
```
== [unknown-keys.yml as grantiva.yml] timeout 120 $G run --no-build
 rc=1 stdout=0B
 ERR| Error: Invalid argument: No screens or flows configured in grantiva.yml
```

## Repro
```
mkdir -p /tmp/c19 && cp fixtures/config/unknown-keys.yml /tmp/c19/grantiva.yml && cd /tmp/c19   # branch qa/cli
grantiva run --no-build; echo rc=$?
```
The fixture is:
```
schem: Landmarks
simulator: qa-cli-1
bundle_id: com.kylebrowning.Landmarks
screen:
  - name: Home
    path: launch
```

## Evidence
- findings/evidence/cli/detect/config.txt

## Suspected cause
Sources/GrantivaCore/Config/GrantivaConfig.swift:127 (`init(from:)`) decodes a keyed container and ignores keys not in
`CodingKeys` (:91); `load` (:185-225) never compares the document's top-level keys with the known set. Same for
`AndroidProject` and `Screen.Step` (:49-50).

## Acceptance criteria
- Re-running the repro prints, on stderr, `grantiva.yml:1: unknown key "schem" (did you mean "scheme"?)` and
  `grantiva.yml:4: unknown key "screen" (did you mean "screens"?)` before the existing error. Warning (not error) keeps
  old configs working; `doctor` reports the same as a Project warning.
- Maestro-format files are not affected.
- GrantivaCoreTests/GrantivaConfigPlatformTests: loading the fixture yields two unknown-key diagnostics with line numbers.
