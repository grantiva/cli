# The "No scheme specified" error tells `build build` users to pass `--app-file`, an option `build build` does not have

Severity: ux
Component: cli
Platforms: ios (iOS-only: scheme resolution; no Android twin expected)
Rows: IOS-027 (ios)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
A remediation line names only options the failing command accepts. Brief I13 (matrix row IOS-027, changed) asks for
`No scheme specified` listing `Found: Landmarks, Landmarks (UI Testing)`; that part holds. `build build` has no
`--app-file` (findings/help/build_build.txt; the option exists on `build install`, `run`, `diff capture`,
`diff compare` and `ci run`).

## Actual
noscheme1.err / noscheme2.err, `grantiva build build --simulator <cov-ios-1>`, exit 1:
```
Error: Invalid argument: No scheme specified. Pass --scheme, set it in grantiva.yml, or use --app-file to provide a pre-built binary. Found: Landmarks, Landmarks (UI Testing).
```
Following the advice fails: `build build` rejects `--app-file` as an unknown option.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k71
unset GRANTIVA_API_KEY
rm -rf /tmp/k71 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k71 && cd /tmp/k71/ios   # 4e49dc4
sed -i '' '/^scheme:/d' grantiva.yml; rm -rf .grantiva
UDID=$(grantiva simulator ensure --name "fix-k71 iPhone 17" --runtime 26.0)
grantiva build build --simulator "$UDID"; echo "exit=$?"
grantiva build build --simulator "$UDID" --app-file x.app; echo "exit=$?"     # Unknown option
grantiva simulator teardown --session-id fix-k71
```

## Evidence
- findings/evidence/cov-ios/IOS-027/commands.txt, noscheme1.err, noscheme2.err, grantiva.yml, schemes.txt
- findings/help/build_build.txt (no `--app-file`), findings/help/build_install.txt (has it)

## Suspected cause
One string serves every command:
- `Sources/GrantivaCore/Config/ProjectResolver.swift:105` (`noSchemeMessage`, thrown at :108 and :114).
- `Sources/GrantivaCore/Platform/IOSPlatform.swift:36` (same text, thrown by `build` when the resolved scheme is nil).
`ProjectResolver.resolve` has no notion of which command called it, so it cannot tailor the advice.

## Acceptance criteria
- `build build` with no scheme (one or several detected): the message offers `--scheme` and `scheme:` in
  grantiva.yml only, plus the `Found: …` list when several schemes exist.
- `build install`, `run` and `diff capture` still mention `--app-file`.
- The MCP `grantiva_build` / `grantiva_run` text is unaffected or follows the same rule (no CLI flag names there).
- GrantivaCoreTests/ProjectResolutionTests (or GrantivaCLITests/BuildCommandTests): resolving without a scheme for a
  caller that cannot take a pre-built binary yields a message without `--app-file`; for one that can, with it.
