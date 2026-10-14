# Changelog

## 2.1.0

### Changed

- The bundled runner is now `1.1.28-grantiva.16`; its Android focused-input handling distinguishes appended text from replacement text so typing preserves the expected field value.
- On Android, `--env`, flow-header `env:`, and `launchApp: environment:` values are merged into the staged `launchApp.arguments` map and delivered to the app as string intent extras.
- Screen capture waits for the UI to settle after every tap, swipe, type, and nested flow, and before every screenshot. Each settle wait is bounded at five seconds, which can add up to five seconds of latency per wait.
