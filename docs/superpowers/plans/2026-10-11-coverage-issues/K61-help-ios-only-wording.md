# Help text for commands and options that serve both platforms describes only the iOS driver or iOS app files

Severity: docs
Component: cli
Platforms: n/a (help text; misleads Android users)
Rows: CLI-008, CLI-111, CLI-119, CLI-123, CLI-125, N-07 (cli), AND-OBS-02 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Help for both-platform commands and options names both drivers or both app formats:
- README:333 lists `grantiva runner start  Start the runner with WDA (UIAutomator2 on Android) and keep it alive for
  interactive use` (README is checked line by line against help abstracts, CLI-111).
- docs/android.md:48 documents `--app-file` with an APK on Android.
- docs/dump-hierarchy.md:57: `runner dump-hierarchy` serves `runner start` and keep-alive sessions on both platforms;
  `hierarchy --help` itself says it reads "from GrantivaAgent on iOS, from the UIAutomator2 server on Android".

## Actual
From the help corpus (findings/help/, byte-identical to `--help` per CLI-003):
```
runner_start.txt:1          OVERVIEW: Start the runner with WDA and keep it alive for interactive use.
runner.txt:12               start   Start the runner with WDA and keep it alive for ...
runner_dump-hierarchy.txt:12  -p, --port <port>   WDA port (auto-detected from active session if omitted)
hierarchy.txt:33            --timeout <timeout>  Seconds to wait for GrantivaAgent's page-source response. Default: 60.
run.txt:13, diff_capture.txt:12, build_install.txt:13
                            --app-file <app-file>  Path to a pre-built .app bundle or .ipa archive. Skips the build step.
```
README:333 and the `runner start` abstract disagree (CLI-111, CLI-123, N-07 are the same finding).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH"
grantiva runner start --help | head -1
grantiva runner --help | grep start
grantiva runner dump-hierarchy --help | grep -A1 -- --port
grantiva hierarchy --help | grep -A1 -- --timeout
for c in "run" "diff capture" "build install"; do grantiva $c --help | grep -A1 -- --app-file; done
grep -n "runner start  " /Users/kyle/Developer/grantiva-cli/README.md
```

## Evidence
- findings/evidence/cov-cli/CLI-008/runner_dump-hierarchy.out
- findings/evidence/cov-cli/CLI-111/compare.out (README vs help abstracts)
- findings/evidence/cov-cli/CLI-119/appfile.out, overviews.out
- findings/evidence/cov-cli/CLI-123/help.out, readme.out; findings/evidence/cov-cli/N-07/help.out
- findings/evidence/cov-cli/CLI-125/help.out
- findings/evidence/cov-android/AND-OBS-02/commands.txt (points at findings/help/build_install.txt)

## Suspected cause
- Sources/GrantivaCLI/DriverCommand.swift:76 (`runner start` abstract, also shown in `runner --help`).
- Sources/GrantivaCLI/DriverCommand.swift:699 (`dump-hierarchy --port` help). The runtime label already switches by
  platform (`portLabel`, DriverCommand.swift:268-270).
- Sources/GrantivaCLI/HierarchyCommand.swift:38 (`--timeout` help).
- Sources/GrantivaCLI/Options.swift:39 (`--app-file`, shared by run, diff capture, build install).
- Related, owned by cluster C11: run.txt:40 `--keep-alive  Keep GrantivaAgent session alive ...` (RunCommand.swift:20).

## Acceptance criteria
- `runner start --help` OVERVIEW and `runner --help` read `Start the runner with WDA (UIAutomator2 on Android) and keep
  it alive for interactive use.`, matching README:333 exactly.
- `dump-hierarchy --port`: `Driver port: WDA on iOS, the forwarded UIAutomator2 port on Android (auto-detected from the
  active session if omitted)` or equivalent naming both.
- `hierarchy --timeout`: names both (`GrantivaAgent's (iOS) or UIAutomator2's (Android) page-source response`).
- `--app-file`: `Path to a pre-built app: .app bundle or .ipa archive (iOS), .apk (Android). Skips the build step.`
- The help corpus is regenerated (findings/help) and CLI-111's README comparison passes.
- GrantivaCLITests (a help test, e.g. in RunnerLifecycleCommandTests and InstallCommandTests): the four help strings
  contain both platform names; a test (or the existing README-vs-help check, if one exists) keeps README:333 and the
  abstract equal.
