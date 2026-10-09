# Name the platform's missing config file when run has nothing to do

Severity: ux
Platforms: cli, ios, android
Found by: CLI-F05 (matrix rows CLI-024, CLI-038)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
With no config file, an error naming the missing file for the resolved platform and how to create it
(`grantiva init --platform android`). Source: CHANGELOG Unreleased ("an error naming the missing file").

## Actual
Same message for iOS and Android, with or without a config file:
```
$ grantiva run --no-build --platform android      # dir holds only settings.gradle.kts
Error: Invalid argument: No screens or flows configured in grantiva.yml
```

## Repro
```
cp -R fixtures/detect/gradle-only /tmp/c18 && cd /tmp/c18     # fixtures on branch qa/cli
grantiva run --no-build --platform android; echo rc=$?
cd $(mktemp -d) && grantiva run --no-build; echo rc=$?
```

## Evidence
- findings/evidence/cli/detect/detect.txt ([gradle-only], [neither], [xcode-only] run rows)

## Suspected cause
Sources/GrantivaCLI/RunCommand.swift:157-158 hardcodes `grantiva.yml` and does not distinguish "no file" from "a file
with no screens or flows".

## Acceptance criteria
- Re-running the repro: Android says `No grantiva-android.yml here. Create one with grantiva init --platform android.`;
  iOS with no file says the same for `grantiva.yml` / `grantiva init`; a file with nothing in it says
  `No screens or flows configured in <resolved file name>`.
- GrantivaCLITests/RunCommandTests: no-config Android and empty-config cases assert the respective messages.
