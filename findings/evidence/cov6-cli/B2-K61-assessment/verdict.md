# B2-K61 candidate5 clause assessment

Verdict: **PASS**.

Expected: `runner start --help` OVERVIEW and `runner --help` read `Start the runner with WDA (UIAutomator2 on Android) and keep it alive for interactive use.`, matching README:333 exactly. • `dump-hierarchy --port`: `Driver port: WDA on iOS, the forwarded UIAutomator2 port on Android (auto-detected from the active session if omitted)` or equivalent naming both. • `hierarchy --timeout`: names both (`GrantivaAgent's (iOS) or UIAutomator2's (Android) page-source response`). • `--app-file`: `Path to a pre-built app: .app bundle or .ipa archive (iOS), .apk (Android). Skips the build step.` • The help corpus is regenerated (findings/help) and CLI-111's README comparison passes. • GrantivaCLITests (a help test, e.g. in RunnerLifecycleCommandTests and InstallCommandTests): the four help strings contain both platform names; a test (or the existing README-vs-help check, if one exists) keeps README:333 and the abstract equal. (brief K61 Acceptance criteria; Platforms: n/a)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B2-K61-run-1/capture.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `capture.stdout`, `capture.stderr` retained.
- `B2-K61-run-1/ci.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `ci.stdout`, `ci.stderr` retained.
- `B2-K61-run-1/dump.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `dump.stdout`, `dump.stderr` retained.
- `B2-K61-run-1/hierarchy.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `hierarchy.stdout`, `hierarchy.stderr` retained.
- `B2-K61-run-1/install.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `install.stdout`, `install.stderr` retained.
- `B2-K61-run-1/run.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `run.stdout`, `run.stderr` retained.
- `B2-K61-run-1/runner.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `runner.stdout`, `runner.stderr` retained.
- `B2-K61-run-1/start.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `start.stdout`, `start.stderr` retained.
