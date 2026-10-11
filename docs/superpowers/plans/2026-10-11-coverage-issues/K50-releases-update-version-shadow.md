# `console releases update --version` cannot print the CLI version: the command's own `--version <version>` option shadows it

Severity: wrong-result
Component: cli
Platforms: n/a
Rows: CLI-170 (cli)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
`<command> --version` prints `2.1.0`, exit 0, on every page (matrix CLI-170: every help page lists the inherited
`--version` flag), or the page does not list an inherited `--version` it cannot honour.

## Actual
171 of 172 pages print `2.1.0`. `console releases update --version` (findings/evidence/cov-cli/CLI-170/all.out:108-111):
```
console_releases_update rc=64 out=Error: Missing value for '--version <version>'
Help:  --version <version>  New version.
Usage: grantiva console releases update [--json] [--verbose] [--quiet] <note> [--version <version>] [--title <title>] [--body <body>]
```
Its help page lists both (findings/help/console_releases_update.txt:16 and :19):
```
  --version <version>     New version.
  --version               Show the version.
```
`console releases create` takes the version as a positional argument and is unaffected.

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"; unset GRANTIVA_API_KEY
grantiva console releases update --version; echo "exit $?"
grantiva console releases update --help | grep -n -- --version
grantiva console releases update NOTE-ID --version 2.2.0; echo "exit $?"   # the option itself (needs auth; expect an auth error, not a parse error)
```
No network call is needed for the first two lines.

## Evidence
- findings/evidence/cov-cli/CLI-170/commands.txt, ver.sh, all.out (lines 108-111)
- findings/help/console_releases_update.txt (lines 16, 19)

## Suspected cause
- Sources/GrantivaCLI/ConsoleReleasesCommand.swift:173-174: `@Option(name: .long, help: "New version.") var version:
  String?` in `UpdateCommand` uses the long name `--version`, which ArgumentParser also reserves for the root command's
  version flag (Sources/GrantivaCLI/GrantivaCommand.swift:9, `version: grantivaVersion`). It is the only `@Option`
  named `version` in Sources/GrantivaCLI.

## Acceptance criteria
- The option is renamed (for example `--release-version` or `--app-version`, keeping a deprecated hidden alias only if
  ArgumentParser allows it without the clash); `grantiva console releases update --version` prints `2.1.0`, exit 0.
- The help page lists one `--version` (the inherited flag) and the renamed option; README/docs mentioning
  `releases update --version` are updated.
- GrantivaCLITests/ConsoleVRTReleasesCommandTests: parsing `update NOTE --release-version 2.2.0` sets the new version;
  a test over every subcommand's help (or `ConsoleReleasesCommand.UpdateCommand.helpMessage()`) asserts `--version`
  appears once.
