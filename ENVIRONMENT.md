# ENVIRONMENT.md — grantiva/cli

Local development setup for the Grantiva CLI (Swift / SwiftPM).

Last verified: 2026-08-14 on macOS (Apple Silicon), Swift 6.4.

## Toolchain

| Tool  | Version used to verify | Minimum |
|-------|------------------------|---------|
| Swift | 6.4 (Apple Swift, Xcode toolchain) | 6.1 (`swift-tools-version: 6.1`) |
| Xcode | 16+ | 16+ |
| macOS | 15+ (Sequoia) | 15 (`platforms: [.macOS(.v15)]`) |

The CLI itself drives the iOS Simulator via a bundled Maestro runner, so a working
Xcode + Simulator install is required to *use* it (not to build/test it).

## Build

```bash
git clone git@github.com:grantiva/cli.git
cd cli
swift build            # debug
swift build -c release # release binary at .build/release/grantiva
```

No environment variables or external services are needed to build. Dependencies
(swift-argument-parser, swift-log, Yams, modelcontextprotocol/swift-sdk) are
resolved from `Package.resolved`.

**Verified:** `swift build` completes clean; `./.build/debug/grantiva --version` → `1.5.5`.

## Test

```bash
swift test
```

**Verified 2026-08-14:** all green.

```
GrantivaCoreTests  — Executed 32 tests, 0 failures
GrantivaAPITests   — Executed 15 tests, 0 failures
Total: 47 tests, 0 failures, no flakes observed.
```

`GrantivaCLITests` and `GrantivaMCPTests` targets exist but currently contain no
`@Test`/`XCTestCase` cases (swift-testing reports "0 tests" for them) — expected,
not a failure.

## Run

```bash
grantiva doctor          # check environment & dependencies
grantiva runner install  # extract the embedded Maestro runner (once per install)
grantiva --help          # list subcommands
```

Subcommands: `build`, `run`, `hierarchy`, `ci`, `diff`, `auth`, `doctor`, and more
(`grantiva --help`).

## Gotchas

- **Embedded runner resources.** `GrantivaCore` copies
  `Resources/grantiva-runner-{arm64,amd64}.tar.gz` into the bundle. These are
  committed binaries — a shallow/partial checkout that skips them will fail to build.
- **Release install.** The README's install path copies `.build/release/grantiva`
  to `/usr/local/bin`; on Apple Silicon that dir may require `sudo` or not be on
  `PATH` — prefer `~/.local/bin` or Homebrew (`brew install grantiva/tap/grantiva`).
- **Simulator required at runtime.** `swift test` needs no Simulator, but
  `grantiva run`/`diff`/`ci` do — run `grantiva doctor` first.
