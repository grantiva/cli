# Changelog

## Unreleased

### Fixed

- Android emulator selection waits for the operating system to finish booting when ADB already reports the emulator as connected.

## 2.1.0

### Changed

- JSON output encodes dates as ISO 8601 UTC strings, for example `2026-10-14T15:43:12Z`, rather than numeric timestamps.
- Android `build install --json` identifies the installed `applicationId` and the target `device` by `name` and `serial`.
- Native screen steps accept `{text: "…", exact: true}` mappings for `tap`, `assert_visible`, and `assert_not_visible`.
- The bundled runner is now `1.1.28-grantiva.17`; indexed iOS taps select distinct actionable targets, and Android Unicode input recovers focus. Android focused input appends text and reports unexpected replacement instead of silently marking it successful.
- On Android, `--env`, flow-header `env:`, and `launchApp: environment:` values are merged into the staged `launchApp.arguments` map and delivered to the app as string intent extras.
- Screen capture waits for the UI to settle after every tap, swipe, type, and nested flow, and before every screenshot. Each settle wait is bounded at five seconds, which can add up to five seconds of latency per wait.
