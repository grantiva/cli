# iOS attempt107 and retained device-resolution/source joins

Candidate provenance: Grantiva CLI `8f2cff67`. Historical round-2 runtime evidence is excluded.

## N-04: PASS

Attempt107 executes three independent cycles of the exact sequence: MCP `grantiva_vrt_capture` through a live runner session, `runner stop`, then CLI `diff capture --no-build`. In every cycle:

- MCP capture succeeds and returns exactly five screens on `cov3-ios-26`, including Detail. The Detail steps tap `Golden Gate Bridge` and assert `Plan Visit`, all passed.
- `runner stop` exits 0.
- CLI capture exits 0 and returns five screen results; the frozen image directory contains `Home.png`, `Favorites.png`, `Deep Links.png`, `Lakes.png`, and `Detail.png`.

This meets the row's “Detail/Golden Gate Bridge found; 5/5; repeat 3 times” contract without joining results from unrelated sessions.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt107/`.

## B-I02.1: PASS by current runtime join

Attempt64 (`ios090.out` and `ios090-captures`) runs capture with both owned simulators booted and the config naming `cov3-ios-26`. It selects U1 and captures five plain-name PNGs. `u2-app-container-before.txt` and `u2-app-container-after.txt`, together with simulator before/after inventories, prove U2 remained booted with the same installed-app container and was not used or altered. This closes the earlier audit's only stated gap.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt64/`.

## B-I02.2: PASS by current runtime plus exact semantic-source join

Current runtime covers the observable tiers that require real environment behavior:

- attempt64 proves config selection with multiple booted simulators;
- attempt32 proves the runner-session fallback and the ambiguous-multiple-booted refusal that names the candidates before device work;
- existing session-backed capture evidence proves the session UDID is actually used.

Exact-head semantic tests pin the full priority order without requiring another protected-device run:

- `DiffCommandTests.testNoBuildFlagWinsOverConfigAndSession` asserts flag > config > session;
- `testNoBuildDoesNotLookUpTheSessionWhenADeviceIsNamed` and `testNoBuildUsesConfiguredSimulatorNotFirstBooted` assert config precedence;
- `testNoBuildFallsBackToTheRunnerSessionDevice` asserts session fallback;
- `testNoBuildUsesThePlatformDefaultOnlyWhenNothingIsNamed` plus `DefaultSimulatorCommandTests.testTheSoleBootedSimulatorIsRefusedUnlessGrantivaCreatedIt` cover the final sole-booted tier and ownership guard.

Source paths: `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCLITests/DiffCommandTests.swift:454-625` and `DefaultSimulatorCommandTests.swift:100-130`. Under the campaign plan's semantic-source rule, these exact assertions supply the precedence clauses that would otherwise require manipulating protected owner devices.

## B-C01.2: still missing current runtime evidence

No allowed current-round capture was found for the exact concurrent repro: slow flow holding the simulator lease while `runner install` performs a real re-extraction, with before/after hashes proving that only runner/version/drivers changed and locks, reports, and `grantiva-wda.xcconfig` remained byte-identical. Existing runner-install evidence is device-free/idempotent or historical; it cannot establish concurrent lease preservation. Keep ungraded. The minimum missing artifact is the before/after hash manifest plus the slow-flow and extracting-install exits from a scratch runner home; source existence alone does not replace this observable criterion.
