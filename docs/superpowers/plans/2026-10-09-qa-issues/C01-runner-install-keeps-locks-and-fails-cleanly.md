# Install the runner without deleting live lease locks, and fail cleanly when the resource bundle is missing

Severity: crash
Platforms: cli, ios, android
Found by: CLI-F23 (matrix rows CLI-084)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
`runner install` repairs a damaged install and never breaks a working one; state other processes rely on
(`~/.grantiva/runner/locks/`, `reports/`, `grantiva-wda.xcconfig`) survives a re-extract. Source: help: runner install
("Extract the embedded GrantivaAgent runner"); README §Commands.

## Actual
With the binary copied away from its `grantiva_GrantivaCore.bundle`, a re-extract deletes `~/.grantiva/runner` and then traps:
```
Extracting runner...
GrantivaCore/resource_bundle_accessor.swift:44: Fatal error: unable to find bundle named grantiva_GrantivaCore
time: command terminated abnormally
rc=133
cat: /Users/kyle/.grantiva/runner/version: No such file or directory
ls: /Users/kyle/.grantiva/runner/grantiva-runner: No such file or directory
```
Lost: `grantiva-runner`, `version`, `drivers/`, `locks/` (simulator leases held by other running processes), `reports/`,
`grantiva-wda.xcconfig`. Only `cache/` survived. Even with the bundle present, every re-extract deletes `locks/`, so a new
process can lease a simulator a running process still holds.

## Repro
Warning: this touches the real `~/.grantiva` (`HOME` is ignored). Do it on a machine with no other Grantiva runs.
1. Build, then copy the bare executable without its bundle:
   ```
   swift build -c release
   mkdir -p /tmp/nobundle && cp .build/release/grantiva /tmp/nobundle/grantiva
   ```
2. Force a re-extract and run the bare copy:
   ```
   ls ~/.grantiva/runner/locks
   printf garbage > ~/.grantiva/runner/version
   /tmp/nobundle/grantiva runner install; echo rc=$?
   ls -la ~/.grantiva/runner
   ```
3. Repair with `.build/release/grantiva runner install`.

## Evidence
- findings/evidence/cli/runner/runner-install.txt ("runner install after tamper" and "aftermath")

## Suspected cause
Sources/GrantivaCore/Runner/RunnerManager.swift:138 removes the whole `baseDir` before `extract(baseDir)` at :141, so
`locks/`, `reports/` and the xcconfig go with it, and nothing is restored on failure. The resources are read through
`Bundle.module` (RunnerManager.swift:31, :35), whose generated accessor calls `fatalError` when the bundle is absent.

## Acceptance criteria
- Re-running the repro exits non-zero with a `GrantivaError` naming the missing resource bundle, no SIGTRAP, and leaves
  `~/.grantiva/runner` exactly as it was.
- With the bundle present, a re-extract replaces only the runner binary, `version` and `drivers/`; files in `locks/` and
  `reports/` and `grantiva-wda.xcconfig` keep their contents (extract into a temp dir, then swap).
- GrantivaCoreTests/RunnerManagerTests: a test with a fake `extract` and a seeded `locks/lease` file asserts the lock
  survives `installIfNeeded`, and a test with a throwing `extract` asserts the previous install is intact.
- Resolve resources with `Bundle(url:)`/a lookup that returns nil instead of `Bundle.module`, so a missing bundle throws.
