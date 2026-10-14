# B2-K50 candidate5 clause assessment

Verdict: **PASS**.

Expected: The option is renamed (for example `--release-version` or `--app-version`, keeping a deprecated hidden alias only if ArgumentParser allows it without the clash); `grantiva console releases update --version` prints `2.1.0`, exit 0. • The help page lists one `--version` (the inherited flag) and the renamed option; README/docs mentioning `releases update --version` are updated. • GrantivaCLITests/ConsoleVRTReleasesCommandTests: parsing `update NOTE --release-version 2.2.0` sets the new version; a test over every subcommand's help (or `ConsoleReleasesCommand.UpdateCommand.helpMessage()`) asserts `--version` appears once. (brief K50 Acceptance criteria; Platforms: n/a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K50-run-1/help.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `help.stdout`, `help.stderr` retained.
- `B2-K50-run-1/release-version.command.json`: exit 1, timedOut=false, cleanupFailed=false; raw `release-version.stdout`, `release-version.stderr` retained.
- `B2-K50-run-1/version.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `version.stdout`, `version.stderr` retained.
