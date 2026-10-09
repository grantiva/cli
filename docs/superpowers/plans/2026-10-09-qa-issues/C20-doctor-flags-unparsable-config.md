# Flag an unparsable config in doctor

Severity: ux
Platforms: cli, ios, android
Found by: CLI-F10 (matrix rows CLI-037)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`doctor` flags a config that `run` will refuse, with "an error naming the file and the YAML position". Source: CHANGELOG
Unreleased Added ("A config file that exists but does not parse is now an error naming the file and the YAML position").

## Actual
```
$ grantiva doctor --platform android | grep -i yml
    ✓ grantiva-android.yml  Found
$ grantiva run --no-build --platform android
Error: Invalid argument: grantiva-android.yml could not be parsed: 5:3: error: parser: while parsing a block collection in line 3, column 3
did not find expected '-' indicator:
  bad: : :
  ^
```

## Repro
```
mkdir -p /tmp/c20 && cp fixtures/config/malformed-android.yml /tmp/c20/grantiva-android.yml && cd /tmp/c20   # branch qa/cli
grantiva doctor --platform android | grep -i yml
grantiva run --no-build --platform android
```

## Evidence
- findings/evidence/cli/detect/config.txt

## Suspected cause
Sources/GrantivaCore/Doctor/DoctorRunner.swift:182-185 (`checkConfig`) only tests `fileExists` and returns `.ok "Found"`.

## Acceptance criteria
- Re-running the repro, doctor shows `✗ grantiva-android.yml  could not be parsed: 5:3: ...` with status error (a Project
  check, so whether it fails the exit code follows the existing section rules) and fix text pointing at the file.
- `checkConfig` loads the file through the same `GrantivaConfig.load` path `run` uses.
- GrantivaCoreTests/DoctorTests: a malformed file in a temp dir yields a non-ok status containing "5:3".
