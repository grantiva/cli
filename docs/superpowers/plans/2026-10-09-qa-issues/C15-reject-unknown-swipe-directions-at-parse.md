# Reject unknown swipe directions when parsing screens

Severity: contract
Platforms: cli, ios, android
Found by: CLI-F24 (matrix rows CLI-047)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`swipe:` accepts only `up`, `down`, `left`, `right`; anything else is a config error before any device work. Source:
README §Screens (README.md:122, "swipe in a direction (`up`, `down`, `left`, `right`)").

## Actual
`swipe: diagonal` parses, the runner boots the simulator, launches the app, and only then fails:
```
    ✓ launchApp (2.1s)
    ✗ swipe: DIAGONAL (0ms)
      ╰─ Invalid swipe direction (cause: invalid direction: DIAGONAL)
```

## Repro
1. Boot a simulator (`udid=$(grantiva simulator ensure --name "iPhone 17 Pro")`).
2. From the qa-cli worktree (branch qa/cli):
   ```
   mkdir -p /tmp/c15 && cp fixtures/config/swipe-diagonal.yml /tmp/c15/grantiva.yml && cd /tmp/c15
   grantiva run --no-build --simulator "$udid" --bundle-id com.apple.Preferences --timeout 120
   ```

## Evidence
- findings/evidence/cli/flows/swipe-diagonal.txt

## Suspected cause
Sources/GrantivaCore/Runner/FlowGenerator.swift:96 (`default: return direction.uppercased()`) passes any string through,
and GrantivaConfig.Screen.Step decodes `swipe` as a free `String?` (Sources/GrantivaCore/Config/GrantivaConfig.swift:28)
with no validation.

## Acceptance criteria
- Re-running the repro fails before booting with an error naming the file, the screen and the value, e.g.
  `grantiva.yml: screen "Diag": swipe direction "diagonal" is not one of up, down, left, right`.
- Directions are case-insensitive (`UP` still works).
- GrantivaCoreTests: a GrantivaConfig decoding test asserts `swipe: diagonal` throws and `swipe: Up` decodes.
