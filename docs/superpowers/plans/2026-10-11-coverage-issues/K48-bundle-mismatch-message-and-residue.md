# A resource bundle from another release fails `runner install` with a generic message and leaves an empty install directory

Severity: wrong-result
Component: cli
Platforms: n/a
Rows: CLI-142 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:186: "An install first checks that the extracted runner's `--version` matches the version grantiva expects; a
mismatch (a `grantiva_GrantivaCore.bundle` from another release beside the binary) fails, names both versions and the
bundle, and leaves the existing install untouched." A failed install leaves no new directories behind.

## Actual
2.1.0 binary beside the 2.0.0 `grantiva_GrantivaCore.bundle` (copied from the Homebrew 2.0.0 keg; its Resources hold
only `grantiva-runner-amd64.tar.gz` and `grantiva-runner-arm64.tar.gz`, findings/evidence/cov-cli/CLI-142/setup.out).
- Fresh runner home (install_fresh.out), exit 1:
```
Extracting runner...
Error: Runner binary not found. The embedded grantiva-runner could not be extracted.
rc=1
fresh/locks/install-1.1.28-grantiva.9+android-drivers-2.lock
fresh/versions/1.1.28-grantiva.9+android-drivers-2
```
  Neither version nor the bundle is named, and `versions/1.1.28-grantiva.9+android-drivers-2/` is left empty.
- Existing current install (install_existing.out): exit 0, install untouched (sha lists identical), mismatch not
  reported. This half is arguably correct (nothing is extracted, so the bundle is never used); see the criteria.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
rm -rf /tmp/k48 && mkdir -p /tmp/k48/bin && cd /tmp/k48
cp "$HOME/.grantiva-qa/bin/grantiva" bin/
cp -R "$(brew --prefix)/Cellar/grantiva/2.0.0/bin/grantiva_GrantivaCore.bundle" bin/    # any pre-2.1 bundle
ls bin/grantiva_GrantivaCore.bundle/Contents/Resources
GRANTIVA_RUNNER_HOME=$PWD/fresh ./bin/grantiva runner install; echo "exit $?"; find fresh -maxdepth 2
```
If the 2.0.0 keg is gone, build a fake bundle: copy the 2.1.0 bundle and delete `android-drivers.tar.gz` from it (same
code path), and separately replace `grantiva-runner-arm64.tar.gz` with an older runner tarball (version path).

## Evidence
- findings/evidence/cov-cli/CLI-142/commands.txt, setup.out, install_existing.out, install_fresh.out

## Suspected cause
- Sources/GrantivaCore/Runner/RunnerManager.swift:93-96 (`extractEmbedded`): when the bundle lacks
  `grantiva-runner-<arch>.tar.gz` or `android-drivers.tar.gz` it throws `GrantivaError.runnerNotFound`, whose text
  (Sources/GrantivaCore/GrantivaError.swift:57-58) names nothing. A pre-2.1 bundle has no `android-drivers.tar.gz`, so
  the version check `verifyRunnerVersion` (RunnerManager.swift:327-348, called at :168-171 and :282) that produces the
  README's message is never reached.
- RunnerManager.swift:266-270 (`installUnlocked`): `createDirectory(atPath: baseDir ...)` runs before `extract`, and
  nothing removes `baseDir` when extraction or verification fails (the staging dir is removed by `defer`, :270).
- The existing-install case returns at RunnerManager.swift:223-227 before looking at the bundle.

## Acceptance criteria
- Re-running the repro (fresh home): exit 1 with a message naming the bundle path and saying it is from another
  release: either both versions (when the runner tarball is present and reports a version) or which expected file is
  missing (`android-drivers.tar.gz`) plus "Reinstall grantiva so the binary and its bundle match". Never the bare
  `Runner binary not found` text.
- After the failure `fresh/versions/` contains no directory for the stamp (the lock file may stay).
- An existing current install keeps working with a mismatched bundle (exit 0, untouched); README:186 is reworded to say
  the check runs when an install is needed, or `runner install` warns when the bundle beside the binary does not match.
- GrantivaCoreTests/RunnerManagerTests: `extractEmbedded` with a bundle missing `android-drivers.tar.gz` throws an error
  whose text names the bundle path; `installIfNeeded` whose `extract` throws leaves no `baseDir`.
