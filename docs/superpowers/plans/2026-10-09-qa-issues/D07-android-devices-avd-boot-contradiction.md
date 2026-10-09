# Resolve the AVD-boot contradiction in docs/android.md §Devices

Severity: docs
Platforms: cli, android
Found by: CLI-DOCS-F10 (matrix rows CLI-118)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
One consistent statement of how `run` picks an emulator with no `emulator:`. Source: docs/android.md §Devices.

## Actual
docs/android.md:33-35:
```
Only running emulators are considered by default. `emulator:` names the AVD; it is used if
running, booted otherwise. With no `emulator:`, a single running emulator is used, else a
single existing AVD is booted.
```
The first sentence says nothing is booted by default; the third says a single AVD is.

## Repro
```
sed -n 31,38p docs/android.md
sed -n 136,195p Sources/GrantivaCore/Android/EmulatorManager.swift
```

## Evidence
- docs/android.md:33-35

## Suspected cause
The code matches the third sentence: Sources/GrantivaCore/Android/EmulatorManager.swift:141-195 (`selectDevice`) uses a
single running emulator, else waits for a single booting one, else boots the only AVD (:186-188), else lists AVDs.
The first sentence is copied from the spec comment at :136.

## Acceptance criteria
- docs/android.md §Devices drops "Only running emulators are considered by default" and states the order: configured
  AVD (running, else booted); otherwise one running emulator, one booting emulator, or the only AVD (booted); otherwise
  an error listing AVDs.
- The doc comment at EmulatorManager.swift:136 is reworded the same way.
