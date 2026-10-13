# Android context/resources v4, X-011, and iOS65 review

## Android context/resources v4

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K56-X011-MCP076-context-resources-rerun4/`.

All eligible components exit 0 after an exact keep-alive run reaches the Landmarks list.

- **B2-K56 [android]: pass.** Context reports runner PID 75354, serial `emulator-5554`, `application_id: com.kylebrowning.landmarks`, and `driver_port: (forwarded on attach)` rather than zero or an empty value. The copied exact-head `ContextToolTests.swift` semantically covers keep-alive app-ID rendering and unknown legacy values.
- **MCP-076 [android]: pass.** Hierarchy resource returns `application/json` text containing the live Android tree; screenshot resource returns a nonempty base64 blob with `image/png`. The tool/tree control agrees with the same live screen.

The prior v2 starting responses remain excluded diagnostic evidence. V4 uses the exact keep-alive contract and does not overwrite them.

## X-011 paired result: pass

iOS attempt61 and Android v4 both use a live keep-alive session parked on the Landmarks list and preserve XML plus JSON from that state.

- iOS XML roots at `XCUIElementTypeApplication`; Android XML roots at `hierarchy` and retains UIAutomator2 class/bounds attributes.
- Both JSON documents are recursive trees with typed children and numeric complete frames. iOS point geometry is 402×874 at the application root; Android converts the 1080×2400 pixel XML geometry to the documented dp-scale JSON geometry (411×914 at the app content/root layers) and carries `platform: android` at the hierarchy root.
- Both contain the expected Landmarks list content, so this is a same-state structural comparison rather than unrelated hierarchy samples.

These are the documented per-platform roots and point-versus-dp shapes required by X-011.

## iOS attempt65

### D2-09 [ios]: pass

The guarded row-created simulator begins shut down with no installed app. Exact `diff capture --no-build --app-file <Landmarks.app>` boots it, installs the hash-preserved simulator product, captures all five screens, and leaves an installed app container. The retained output and before/after container probes cover every clause.

### D2-08 [ios]: fail on the skipped-install control

The app-file legs are valid:

- `build install --no-build --app-file ... --no-launch` installs and returns JSON `status: installed`;
- `run --no-build --app-file ...` installs and passes browse;
- `diff capture --no-build --app-file ...` installs and captures five screens;
- unauthenticated `ci run --no-build --app-file ...` fails at the explicitly permitted authentication boundary before installation, and the before/after probes confirm no app appeared.

The exact no-app-file control is a product contract failure, not an invalid fixture. After uninstall, `build install --no-build --no-launch` should do nothing to the app and print the required `(install skipped, not launched)` completion. It instead prints `Skipping build and install`, then exits 1 with `NSPOSIXErrorDomain code=2` because `InstallCommand.run` unconditionally calls `dataContainerPath` before `completeInstall`: `BuildCommand.swift:187-191` bypasses the installed-app check only for `--no-launch`, but lines 191 onward still query the absent iOS data container. The later `completeInstall` and `completionMessage` code explicitly define `.skipped` for `--no-build --no-launch`, and exact-head tests/JSON contracts encode that status. The row-created device, config bundle ID, and flags are valid; the missing app is the scenario the skipped behavior must tolerate.

D2-08 should therefore retain all successful subcase evidence and grade **fail** on this one clause. This is suitable for a focused defect brief; it is not a matrix correction.

