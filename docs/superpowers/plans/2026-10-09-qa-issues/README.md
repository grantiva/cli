# CLI QA bug briefs (2026-10-09)

These briefs were found against grantiva 2.0.1 built from commit c8dc86d on 2026-10-09, and reproduced against grantiva/landmarks-demo (private; bundle `com.kylebrowning.Landmarks`), with `com.apple.Preferences` standing in where no app build was needed. Each file is a self-contained, fix-ready brief for one proposed issue from `findings/cli-triage.md`: C-nn are CLI behavior bugs, D-nn are documentation bugs, each numbered in the triage's severity order. Evidence and fixture paths are relative to the qa-cli worktree (branch `qa/cli`). iOS and Android briefs (I-nn, A-nn) will be added by a later pass.

| File | Severity | Platforms | Title | Finding IDs |
|---|---|---|---|---|
| [C01-runner-install-keeps-locks-and-fails-cleanly.md](C01-runner-install-keeps-locks-and-fails-cleanly.md) | crash | cli, ios, android | Install the runner without deleting live lease locks, and fail cleanly when the resource bundle is missing | CLI-F23 |
| [C02-emulator-ledger-only-records-own-emulators.md](C02-emulator-ledger-only-records-own-emulators.md) | wrong-result | cli, android | Never record, or later tear down, an emulator Grantiva did not boot itself | CLI-F04 |
| [C03-mcp-restrict-to-own-runner-session.md](C03-mcp-restrict-to-own-runner-session.md) | wrong-result | cli, ios, android | Restrict the MCP server to its own project's runner session | CLI-F21 |
| [C04-screens-runs-honour-report-dir-timeout-continue.md](C04-screens-runs-honour-report-dir-timeout-continue.md) | wrong-result | cli, ios, android | Honour --report-dir, --timeout, and --continue-on-failure for screens runs | CLI-F08 |
| [C05-mcp-vrt-tools-use-own-executable.md](C05-mcp-vrt-tools-use-own-executable.md) | wrong-result | cli, ios, android | Run MCP VRT tools with the server's own executable | CLI-F19 |
| [C06-grantiva-context-reports-session-device.md](C06-grantiva-context-reports-session-device.md) | wrong-result | cli, ios | Report the session's device in grantiva_context | CLI-F20 |
| [C07-maestro-parser-accepts-standard-swipe-wait-forms.md](C07-maestro-parser-accepts-standard-swipe-wait-forms.md) | wrong-result | cli, ios | Accept the standard Maestro swipe, extendedWaitUntil, and waitForAnimationToEnd forms, and make README match unsupported-command handling | CLI-F27, CLI-DOCS-F04 |
| [C08-maestro-tapon-id-matches-identifier.md](C08-maestro-tapon-id-matches-identifier.md) | wrong-result | cli, ios | Match Maestro tapOn id against the accessibility identifier, not label text | CLI-F28 |
| [C09-wait-step-waits-n-seconds.md](C09-wait-step-waits-n-seconds.md) | wrong-result | cli, ios, android | Make `wait: N` wait N seconds | CLI-F29 |
| [C10-run-flow-bare-scroll-and-setpermissions.md](C10-run-flow-bare-scroll-and-setpermissions.md) | wrong-result | cli, ios | Support bare `scroll` and header-appId `setPermissions` in `run --flow` | CLI-F30 |
| [C11-mcp-starts-without-session-or-config.md](C11-mcp-starts-without-session-or-config.md) | contract | cli, ios, android | Start the MCP server without a live runner session or config file | CLI-F18 |
| [C12-doctor-init-apply-run-platform-validation.md](C12-doctor-init-apply-run-platform-validation.md) | contract | cli, ios, android | Apply run's platform validation in doctor and init (ambiguous project, bad GRANTIVA_PLATFORM, other-platform flags) | CLI-F06, CLI-F11, CLI-F12 |
| [C13-keep-narration-off-stdout-runner-stop-record.md](C13-keep-narration-off-stdout-runner-stop-record.md) | contract | cli, ios | Keep narration off stdout in runner stop and record | CLI-F02, CLI-F15 |
| [C14-validate-record-arguments-before-recording.md](C14-validate-record-arguments-before-recording.md) | contract | cli, ios | Validate record arguments (--frames-at, --output extension) before recording | CLI-F14, CLI-F16 |
| [C15-reject-unknown-swipe-directions-at-parse.md](C15-reject-unknown-swipe-directions-at-parse.md) | contract | cli, ios, android | Reject unknown swipe directions when parsing screens | CLI-F24 |
| [C16-validate-webhook-event-names-locally.md](C16-validate-webhook-event-names-locally.md) | contract | cli | Validate webhook event names locally and add `console webhooks events` | CLI-F17, CLI-DOCS-F07 |
| [C17-grantiva-script-iserror-on-invalid-steps.md](C17-grantiva-script-iserror-on-invalid-steps.md) | contract | cli, ios, android | Return isError from grantiva_script when steps are invalid | CLI-F22 |
| [D01-hierarchy-json-flag-and-runner-json-docs.md](D01-hierarchy-json-flag-and-runner-json-docs.md) | contract | cli, ios, android | Make `hierarchy --json` select JSON (or drop it), and correct README's JSON-mode statement for runner commands | CLI-DOCS-F12, CLI-DOCS-F02 |
| [C18-run-names-platform-missing-config.md](C18-run-names-platform-missing-config.md) | ux | cli, ios, android | Name the platform's missing config file when run has nothing to do | CLI-F05 |
| [C19-warn-unknown-config-keys.md](C19-warn-unknown-config-keys.md) | ux | cli, ios, android | Warn about unknown keys in grantiva.yml | CLI-F09 |
| [C20-doctor-flags-unparsable-config.md](C20-doctor-flags-unparsable-config.md) | ux | cli, ios, android | Flag an unparsable config in doctor | CLI-F10 |
| [C21-remediation-names-real-commands.md](C21-remediation-names-real-commands.md) | ux | cli, ios | Point error remediation lines at commands that exist | CLI-F13 |
| [C22-sessions-json-iso8601-timestamps.md](C22-sessions-json-iso8601-timestamps.md) | ux | cli, ios, android | Emit Unix or ISO 8601 timestamps in sessions --json | CLI-F25 |
| [C23-doctor-reports-stale-android-home.md](C23-doctor-reports-stale-android-home.md) | ux | cli, android | Report a stale ANDROID_HOME in doctor | CLI-F26 |
| [C24-init-warns-placeholder-values.md](C24-init-warns-placeholder-values.md) | ux | cli, ios | Warn when init writes placeholder scheme and simulator values | CLI-F07 |
| [C25-auth-logout-not-logged-in.md](C25-auth-logout-not-logged-in.md) | ux | cli | Report "not logged in" from auth logout when there are no credentials | CLI-F03 |
| [C26-document-run-continue-snapshot-timeout.md](C26-document-run-continue-snapshot-timeout.md) | docs | cli | Document run's --continue-on-failure, --snapshot, and --timeout minimum | CLI-F01 |
| [D02-readme-commands-match-help.md](D02-readme-commands-match-help.md) | docs | cli | Bring README §Commands in line with help: add emulator, console, and runner dump-hierarchy; fix the cleanup wording; add delete/sessions abstracts; drop the iOS-only wording | CLI-DOCS-F03, CLI-DOCS-F05, CLI-DOCS-F06 |
| [D03-fix-readme-run-device-example.md](D03-fix-readme-run-device-example.md) | docs | cli, ios | Fix the README `run --device "$udid" flows/` example | CLI-DOCS-F01 |
| [D04-help-overviews-cover-android.md](D04-help-overviews-cover-android.md) | docs | cli, android | Update help overviews to cover Android | CLI-DOCS-F11 |
| [D05-changelog-move-shipped-unreleased.md](D05-changelog-move-shipped-unreleased.md) | docs | cli, android | Move shipped Unreleased entries under the version that contains them | CLI-DOCS-F08 |
| [D06-android-environment-ci-run-refuses-android.md](D06-android-environment-ci-run-refuses-android.md) | docs | cli, android | State in android-environment.md that `ci run` refuses Android | CLI-DOCS-F09 |
| [D07-android-devices-avd-boot-contradiction.md](D07-android-devices-avd-boot-contradiction.md) | docs | cli, android | Resolve the AVD-boot contradiction in docs/android.md §Devices | CLI-DOCS-F10 |
| [D08-document-ready-file-creates-parent.md](D08-document-ready-file-creates-parent.md) | docs | cli, ios, android | Document that --ready-file creates missing parent directories | CLI-DOCS-F13 |
| [D09-publish-mcp-tool-list.md](D09-publish-mcp-tool-list.md) | docs | cli, ios, android | Publish the full MCP tool list | CLI-DOCS-F14 |
