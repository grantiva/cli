# Task 0: runner upgrade check (2.1.0 regression pass)

Target: `a278b77` on `main`, built as a release binary at `~/.grantiva-qa/bin/grantiva`.
Runner home under test: `~/.grantiva-qa/runner`, an APFS clone of `~/.grantiva/runner` taken 2026-10-10 before any 2.1.0 binary touched it.

## Before the upgrade

```
version file: 1.1.18-grantiva.7+android-drivers-2
versions/:    1.1.18-grantiva.7+android-drivers-2
cache/wda-builds/:
  sim-ios26.0-iphone
  sim-ios26.0-iphone-wda16.12.8
  sim-ios26.2-iphone
  sim-ios26.4-iphone
  sim-ios27.0-iphone
versions/*/drivers/android/:
  appium-uiautomator2-server-debug-androidTest.apk
  appium-uiautomator2-server-v9.11.1.apk
```

Note: the source home already held `sim-ios26.0-iphone-wda16.12.8`, left over from building the embedded cache for runner 1.1.28-grantiva.8 on 2026-10-10. The other three `-wda16.12.8` directories must appear only through the upgrade.

## Binary

`swift build -c release` on `644a929` (plan commit on top of `a278b77`): `Build complete!`. Copied `.build/release/grantiva` AND `.build/release/grantiva_GrantivaCore.bundle` to `~/.grantiva-qa/bin/`. `grantiva --version` prints `2.1.0`.

## Upgrade: `grantiva runner install` with `GRANTIVA_RUNNER_HOME=~/.grantiva-qa/runner`

```
Extracting runner...
Runner installed at /Users/kyle/.grantiva-qa/runner/versions/1.1.28-grantiva.8+android-drivers-2/grantiva-runner
Version: 1.1.28-grantiva.8

$ grantiva runner version
grantiva-runner 1.1.28-grantiva.8

versions/:
  1.1.18-grantiva.7+android-drivers-2   (version stamp 1.1.18-grantiva.7+android-drivers-2, binary 35065026 bytes, Aug 29)
  1.1.28-grantiva.8+android-drivers-2   (version stamp 1.1.28-grantiva.8+android-drivers-2, binary 37016306 bytes, Oct 10)
cache/wda-builds/:
  sim-ios26.0-iphone
  sim-ios26.0-iphone-wda16.12.8
  sim-ios26.2-iphone
  sim-ios26.2-iphone-wda16.12.8
  sim-ios26.4-iphone
  sim-ios26.4-iphone-wda16.12.8
  sim-ios27.0-iphone
  sim-ios27.0-iphone-wda16.12.8
versions/1.1.28-grantiva.8+android-drivers-2/drivers/android/:
  appium-uiautomator2-server-debug-androidTest.apk
  appium-uiautomator2-server-v9.11.1.apk
```

The real home `~/.grantiva/runner` was not modified (still one `versions/` entry, five cache directories).

## Verdict: PASS (Review Focus item 1)

The new version is extracted beside the old one, every pre-existing cache directory survives, the three missing `-wda16.12.8` caches are merged in from the embedded tarball, and `runner version` reports 1.1.28-grantiva.8.

### Deviations from the plan text, both explained

1. The plan expected `~/.grantiva-qa/runner/version` to read the new stamp. That top-level file is a leftover from the pre-2.0 layout; since the per-stamp install layout, the stamp lives at `versions/<stamp>/version`, which does hold `1.1.28-grantiva.8+android-drivers-2`. Not a regression.
2. The first attempt installed the OLD runner (35 MB, Aug 29) under the new stamp directory, with no new caches. Cause: the plan's Step 1 copies only the `grantiva` binary, and `~/.grantiva-qa/bin/` still held the `grantiva_GrantivaCore.bundle` from the 2.0.1 campaign (Oct 9), which the binary found beside itself and extracted. Fixed by copying the matching bundle; the clone was recreated and the upgrade rerun from a clean state.

### Observation for triage (not a regression against any brief)

`grantiva runner install` does not check that the tarball it extracted matches the version it stamps: with a stale resource bundle beside the binary it wrote the 1.1.18 runner into `versions/1.1.28-grantiva.8+android-drivers-2/`, stamped it `1.1.28-grantiva.8+android-drivers-2`, and `grantiva runner version` (a compile-time constant) reported 1.1.28. A user who upgrades the binary with a package manager that misses the bundle would run the old runner while being told they run the new one. Candidate for a low-severity brief in Task 4.
