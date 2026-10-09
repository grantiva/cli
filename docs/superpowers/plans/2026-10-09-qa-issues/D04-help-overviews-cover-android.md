# Update help overviews to cover Android

Severity: docs
Platforms: cli, android
Found by: CLI-DOCS-F11 (matrix rows CLI-119)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
Commands that support Android say so. Source: README.md:7 ("Android: `init`, `doctor`, `build`, `run`, `diff`, ...
work against an Android emulator"); docs/android.md.

## Actual
```
OVERVIEW: The Grantiva CLI for iOS developers.
OVERVIEW: Run Maestro flows against a simulator. No visual regression — reports ...
OVERVIEW: Build the app for a simulator using xcodebuild.
```
and `run --no-build` says "assume the app is already on the simulator".

## Repro
```
grantiva --help | head -1; grantiva run --help | head -1; grantiva build build --help | head -1
grantiva run --help | grep -A2 -- --no-build
```

## Evidence
- help/grantiva.txt:1, help/run.txt:1, help/build_build.txt:1 (qa-cli worktree root); README.md:3, :7

## Suspected cause
Sources/GrantivaCLI/GrantivaCommand.swift:8, Sources/GrantivaCLI/RunCommand.swift:8,
Sources/GrantivaCLI/BuildCommand.swift:8, :19, :79 and the `--no-build` help string in RunCommand.swift.

## Acceptance criteria
- Overviews read e.g. "The Grantiva CLI for iOS and Android developers.", "Run Maestro flows against a simulator or
  emulator.", "Build the app for a simulator (xcodebuild) or emulator (Gradle).", and `--no-build` says "device".
- README.md:3 tagline updated to match.
- GrantivaCLITests: a test asserts no command abstract contains "simulator" without "emulator" for commands whose
  platform options include Android (or a fixed list check).
