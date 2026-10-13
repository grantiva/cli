# Task 9 primary provisioning evidence review

**Specification verdict: APPROVED. Evidence-quality verdict: APPROVED.** The fresh provisioning evidence binds the accepted candidate and zero gate, creates exactly the three intended primary devices, installs the frozen app artifacts, reaches readiness, and preserves the protected device and forward baselines. No blocking finding was identified.

This approves provisioning only. Devices remain controller-owned; allocation, targeted Android shutdown for the source window, source-window acceptance and later physical cleanup are separate operations. No general slice or coverage-result acceptance is implied.

## Candidate, commands and ownership

Recomputed candidate SHA-256 is `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`; gate SHA-256 is `561d91c5377c52bb373c53527f267223553b3d8a5af6008e3f9118de4f9531c8`. Both match `acceptance.json`. Its embedded ownership equals `ownership.json`, which binds the same candidate, gate, isolated runner home and `cov4-controller` session.

Every completed command has paired start/result metadata with matching initial fields, exit 0, retained raw streams and no timeout. The ordinary command records include exact argv, cwd, timestamps, session, runner home, Java home and API-key-unset state. Raw stderr files are empty. The emulator launch record appropriately records a spawned persistent PID rather than inventing an exit code.

Ownership records bind:

- `cov4-ios-26`: `3B3BBFDB-D435-454F-9DDC-E0CC5EE99E42`, iPhone 17, iOS 26.0.
- `cov4-ios-27`: `989B2045-96AE-46BF-8E13-C76B563FC6F5`, iPhone 17, iOS 27.0.
- `cov4-android`: `emulator-5584`, API 35 google_apis arm64-v8a, launcher PID 82484, exact emulator argv `-avd cov4-android -port 5584 -no-window -no-audio -no-snapshot`.

The two simulator creation stdout records return exactly the owned UUIDs. Their create metadata and ownership timestamps agree; subsequent boot, readiness, install and container commands target only those UUIDs. Android creation and launch records use only the intended AVD and unused port pair.

## Freshness, readiness and installation

Raw initial simulator inventory contains neither new iOS name; initial AVD enumeration contains only `Pixel_8_API_35`; initial ADB inventory is empty. The retained baseline additionally records successful unused-port checks for 5584/5585. Raw final simulator inventory shows both exact new names/UUIDs in the intended runtimes and Booted state. Both `bootstatus -b` commands succeed.

Each iOS install command names the frozen candidate app. Its exact-device container response and retained installed manifest point beneath the corresponding owned UUID. Both installed manifests equal all five frozen source files and hashes; a read-only rehash of both installed bundles also matches. No build or substitute app is involved.

Android live identity returns `cov4-android` and `OK` for serial 5584. Boot readiness completes in approximately 21.4 seconds over 21 probes, inside the 120-second overall deadline; final raw property output is `1`. Installation of the exact frozen APK returns `Success`. The retained installed-artifact record binds source hash `5891bf3753eade9ce28a391ec5d8d3d289d195af951e967b67bb1928e06d988a`, and the package lookup returns the installed `com.kylebrowning.landmarks` base APK. This is successful installation of a hash-verified source APK plus package-presence evidence, not an independent hash of bytes pulled back from Android.

## Protected resources and expected additions

Independently recomputed inventory differences show precisely the two owned simulator additions and no simulator removals. Normalized protected records, excluding only dynamic `dataPathSize`/`logPathSize`, match the baseline and raw before/after inventories for owner UUIDs `B27D7D31-1E5E-47E1-8B9C-6C92D6B2AC4C` and `FE441EE5-BBFC-4981-B68A-59C0DBCE26D6`; both remain Booted.

AVD enumeration adds only `cov4-android` and retains `Pixel_8_API_35`; ADB enumeration adds only `emulator-5584`. Before/after forward streams are identical and empty, agreeing with the normalized comparison. Rehashed protected Pixel configuration remains `3caad1a0f9164280a264968a81249241e183fe4981462fbabf9181e4c18eae27`. These independent raw comparisons support every predicate in `post-provision-comparison.json` and the passing acceptance.

Only retained records and filesystem artifact bytes were read. No live helper, device/process command, test, build or network operation ran. Only this review document was written.
