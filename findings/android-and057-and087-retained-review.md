# Android AND-057 / AND-087 retained-evidence review

## AND-057 — PASS

Current runtime:
`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/dual-device-runtime-exact-rerun1`.

`AND-057/commands.txt` records the exact
`grantiva hierarchy --udid emulator-5554` command and exit 0. The before and
after `adb forward --list` snapshots are byte-identical. They include the
already-owned runner forwards on both active emulators, so the comparison
correctly proves hierarchy did not leak an additional command attachment; it
does not incorrectly require removal of forwards owned by the live runners.

The transient middle state is established by exact-head semantics at CLI head
`8f2cff676b3c12e951478920fa20e600cdca4e29`:

- `Sources/GrantivaCLI/HierarchyCommand.swift:154` attaches for the command.
- `Sources/GrantivaCore/Android/AndroidPlatform.swift:286-323` creates the
  local `tcp:0 -> tcp:6790` attachment and returns cleanup that removes it.
- `Tests/GrantivaCoreTests/AndroidPlatformTests.swift:316-323` asserts the
  exact forward and matching `forward --remove` operations.
- `Tests/GrantivaCLITests/HierarchyCommandTests.swift:76,104` assert hierarchy
  always pairs `attachDriver` with `detach`.

This runtime/source join proves the local attachment exists only for the
command while preserving unrelated live-session forwards, as the row asks.

## AND-087 — PASS

The unchanged half is current runtime at
`findings/evidence/cov3-android/AND-087-unchanged`. Text and JSON comparisons
both exit 0; all five Android screens report zero pixel and perceptual
difference, `passed: true`, and valid decoded JSON.

The changed-pixel half is current, device-free comparison evidence at
`findings/evidence/cov3-android/B2-K108-threshold-wording-devicefree-rerun1`.
Its frozen inputs are retained current Android Home and Deep Links PNGs. The
valid `both-*` case exits 1 in text and JSON, reports pixel 6.42% over 0.03%
and perceptual 44.3 over 22.2, marks the screen failed, and emits the complete
JSON paths, metrics, thresholds, message, and status. The original directory's
purported perceptual-only classification is excluded, but that does not affect
this valid both-threshold case; the later
`B2-K108-perceptual-only-complement1` independently corrected the separate
K108-only leg.

Together these are the exact unchanged-pass, changed-fail-under-both-
thresholds, and valid-JSON outcomes required by AND-087. No complement is
needed.
