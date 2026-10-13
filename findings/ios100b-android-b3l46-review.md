# iOS attempt100b and Android B3-L46 review

Read-only review on 2026-10-13 against the binding round-3 matrix, CLI candidate `8f2cff67`, and retained current-round raw evidence.

## iOS attempt100b

**B-I13.1 [ios], B-I13.2 [ios], and B2-K72 [ios]: pass.** The frozen scheme inventories show exactly one shared scheme for the first two builds. Both exit 0 with the same `Landmarks` scheme and concrete product under the shared Derived Data path. The retained hash manifests then show the byte-identical second shared scheme restored. The next omitted-scheme build using that same Derived Data exits 1 with `No scheme specified` and names both `Landmarks` and `Landmarks (UI Testing)`. This proves silent first and cached one-scheme detection, invalidation when the current project gains a second scheme, and the required ambiguity error. The three ledger grades accurately describe the raw evidence.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt100b/` (`one-scheme-files.txt`, `one-first.*`, `one-cached.*`, `two-scheme-files.txt`, `schemes-before.sha256`, `schemes-restored.sha256`, and `two-after-cache.*`).

## Android B3-L46

**B3-L46 [android]: pass.** The frozen harness performs the matrix sequence three times on the row-owned `cov3-android-retention-r3b` emulator: fresh APK install with `--no-launch`, an intentional five-second wait, verbose JSON teardown, ensure of the same AVD, and package query. Each install exits 0; all three post-reboot queries retain `com.kylebrowning.landmarks`. The three teardown documents are single-element JSON arrays whose sole records have `killed:true`; elapsed times are 2.890, 2.454, and 2.584 seconds.

Each verbose stderr capture records the five-second-alarmed `adb shell sync` command and exit 0 immediately before `adb emu kill` and its exit 0. Exact-head source at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/EmulatorManager.swift:640` places the bounded sync before `emuKill`, while `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCore/Android/ADB.swift:240` implements the alarm. The command help at `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Sources/GrantivaCLI/EmulatorCommand.swift:120` documents that this flush preserves a just-installed app. Cleanup deletes only the row-created AVD; the final adb inventory contains only the pre-existing primary emulator.

The wrapper's nonzero status is fully explained by two audit bugs: it treated the top-level teardown array as an object when testing `killed`, and its final `tr -d '\\r'` expression was malformed. Those defects do not invalidate the retained raw captures. `decoded-posthoc-audit.json` decodes the original files without replacing them and confirms all matrix facts.

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L46-installed-retention-rerun2/`.

## IOS-110 correction

**IOS-110: pass from attempt99.** Matrix row 807 specifies only `ensure {name: "cov-ios-3 iPhone 17"}` followed by delete, expecting a name-only ensure and removal. Attempt99 supplies that exact lifecycle and proves final absence. The heading's tool-family list does not impose a separate simulator-list call.
