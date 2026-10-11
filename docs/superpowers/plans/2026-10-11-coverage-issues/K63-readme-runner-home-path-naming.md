# README names the per-device runner home `versions/<runner version>/`; on disk it is `versions/<stamp>/`

Severity: docs
Component: docs
Platforms: ios (per-simulator WDA homes)
Rows: CLI-161 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README describes the device-home path as it is on disk, and both README passages name the directory the same way.

## Actual
- README:92: "Each simulator launches WebDriverAgent from its own runner home (`<runner
  home>/versions/<runner version>/devices/<udid>` ...)".
- README:186: "one runner install per version under `versions/<stamp>/`".
- On disk the directory is the install stamp `1.1.28-grantiva.9+android-drivers-2`, not the runner version
  `1.1.28-grantiva.9` that `grantiva runner version` prints (findings/evidence/cov-cli/CLI-161/layout.out).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"
grantiva runner version
ls "$GRANTIVA_RUNNER_HOME/versions/"
ls -d "$GRANTIVA_RUNNER_HOME"/versions/*/devices/* 2>/dev/null | head -3
grep -n "versions/<" /Users/kyle/Developer/grantiva-cli/README.md
```

## Evidence
- findings/evidence/cov-cli/CLI-161/commands.txt, layout.out

## Suspected cause
- README.md:92 says `<runner version>`; the code uses `RunnerManager.installStamp = runnerVersion +
  "+android-drivers-2"` (Sources/GrantivaCore/Runner/RunnerManager.swift:23, :28) for the directory
  (`installDir`, :127-129).

## Acceptance criteria
- README:92 reads `<runner home>/versions/<stamp>/devices/<udid>` and explains `<stamp>` once (the runner version plus
  the bundled driver tag, e.g. `1.1.28-grantiva.9+android-drivers-2`), consistent with README:186.
- `grep -n "runner version>/" README.md docs/*.md` finds nothing.
