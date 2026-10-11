# On a cached GrantivaAgent build the runner still narrates `Building GrantivaAgent...` / `GrantivaAgent built`, and prints the start lines twice

Severity: ux
Component: runner
Platforms: ios (iOS-only: GrantivaAgent/WDA setup; the Android narration issue is C11)
Rows: N-18 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix N-18 (plan N18; round-1 smoke; README:92 "without rebuilding WDA"): on a cache hit the narration says it is
using the cached build, without a "Building GrantivaAgent..." / "GrantivaAgent built" pair around it, and each setup
step is printed once.

## Actual
IOS-117/stock-26.err:20-29 (iOS 26.0; IOS-118/stock-27.err is the same with `sim-ios27.0-…`):
```
  ⏳ Checking GrantivaAgent installation...
  ✓ GrantivaAgent installed
  ⏳ Building GrantivaAgent...
  ✓ Using cached GrantivaAgent build (sim-ios26.0-iphone-wda16.12.8-r1)
  ✓ GrantivaAgent built
  ⏳ Starting GrantivaAgent...
Starting GrantivaAgent...
GrantivaAgent started
  ✓ GrantivaAgent started
  ✓ GrantivaAgent port: 8235
```

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k98
unset GRANTIVA_API_KEY
rm -rf /tmp/k98 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k98 && cd /tmp/k98/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k98 iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml 2>&1 | grep -n 'GrantivaAgent'   # first run may build
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml 2>&1 | grep -n 'GrantivaAgent'   # cache hit
grantiva simulator teardown --session-id fix-k98
```

## Evidence
- findings/evidence/cov-ios/IOS-117/commands.txt, stock-26.err (lines 20-29)
- findings/evidence/cov-ios/IOS-118/stock-27.err

## Suspected cause
grantiva-runner:
- `pkg/cli/ios.go:111-122`: prints `⏳ Building GrantivaAgent...` before calling `runner.Build` and
  `✓ GrantivaAgent built` after it, whatever `Build` did.
- `pkg/driver/wda/runner.go:192-197` (`Build`): on a cache hit prints its own `✓ Using cached GrantivaAgent build (…)`
  and returns; the caller cannot tell a hit from a build.
- `pkg/cli/ios.go:125` and :133 print `⏳ Starting GrantivaAgent...` / `✓ GrantivaAgent started`, while
  `pkg/driver/wda/runner.go:391` (`Starting GrantivaAgent...`, first attempt) and :333 (`GrantivaAgent started`)
  print their own unprefixed copies.

## Acceptance criteria
- Re-running the repro (cache hit): exactly one line about the build, `✓ Using cached GrantivaAgent build (<key>)`;
  no `Building GrantivaAgent...` or `GrantivaAgent built`. One `Starting` and one `started` line, both in the
  prefixed style.
- On a cache miss: `⏳ Building GrantivaAgent for the first time…` (with the existing explanation) and `✓ GrantivaAgent
  built`, each once.
- Runner test (pkg/cli or pkg/driver/wda): `Build` reports whether it used the cache (return value or callback), and
  the setup narration for a hit contains no "Building" line.
- Bundled runner version bumped in this repo.
