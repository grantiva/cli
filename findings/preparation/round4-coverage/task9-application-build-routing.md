# Task 9 application-build routing preparation

Status: **PREPARATION ONLY; ROOT RULING REQUIRED.** This note does not amend the canonical matrix or slice briefs, authorize a command, grade a row, or widen the already-open source window. It resolves only how to read a generic slice instruction such as “do not build” when the literal matrix row itself requires building the frozen demo application.

## Literal row inventory

The following fixed keys require a real application compile from a scratch copy of the frozen demo, or a `build install` invocation whose default behavior includes that compile.

### iOS actor

| Key | Literal requirement | Routing consequence |
|---|---|---|
| `IOS-021` | `build build --scheme "Landmarks (UI Testing)" --simulator <UDID>` builds and exits 0. | Fresh scratch iOS app build. |
| `IOS-022` | `build install` builds, installs, and launches. | Fresh scratch build plus owned-device install/launch. |
| `IOS-023` | `build install --no-launch --json`; validate result fields and app not running. | Fresh scratch build plus owned-device install, no launch. |
| `IOS-024` | `build install` with absolute spaced and relative derived-data paths; products land there. | Two scratch derived-data builds; owned-device install behavior. |
| `IOS-025` | `build build` with config `build_settings` derived-data path and overriding CLI path. | Scratch build proving precedence. |
| `IOS-026` | `build build --scheme NoSuchScheme`; clear nonzero scheme error. | Negative scratch project build entry; must not install. |
| `IOS-027` | `build build` with no scheme and two schemes; named ambiguity or allowed warning. | Negative scratch project build entry; must not install. |
| `IOS-028` | `build install --simulator <name>` versus UDID; same destination `id=<UDID>`. | Scratch build/install on the owned iOS device, both target spellings as the row requires. |
| `IOS-123` | `build build --bundle-id com.kylebrowning.Landmarks` accepted and used. | Scratch build-only control. |
| `B2-K71`, `B2-K72` | `build build` no-scheme/cached-scheme diagnostics. | Scratch project mutations/copies only; no candidate/demo checkout edit. |
| `B2-K73` | `build install --no-launch --bundle-id ... --json` mismatch and matching controls. | Scratch build plus owned-device install control. |

The following iOS-owned or cross-platform keys are install/no-build controls and must remain distinct from permission to rebuild the CLI or runner: `D2-07`, `D2-08`, `B2-K25`, `B3-L39`, `B4-L53.P5`, and `B4-L71.1`–`.3`, `.5`. Their literal forms mix default `build install` legs, skipped `--no-build` legs, and frozen `.app` `--app-file` legs. `B4-L71.4` is source-test evidence already routed through the source window and grants no application build. `IOS-014` and `B3-L08.2` mention `build install` as ownership/default-device controls; their precondition/refusal semantics must not be converted into an unnecessary build.

### Android actor

| Key | Literal requirement | Routing consequence |
|---|---|---|
| `AND-019` | Default `build build` runs `assembleFreeDebug`, exit 0. | Fresh scratch Android app build. |
| `AND-020` | Default `build install` builds, installs, launches. | Fresh scratch build plus owned-device install/launch. |
| `AND-021` | `build install --no-launch --json`; validate fields and app not running. | Fresh scratch build plus owned-device install, no launch. |
| `AND-022` | `build build --variant freeRelease`; retain APK and actual signing status. | Fresh scratch release-variant build. |
| `AND-023` | `build build --variant paidDebug` runs `assemblePaidDebug`. | Fresh scratch variant build. |
| `AND-024` | `build build --variant noSuchVariant` text/JSON Gradle reason. | Negative scratch build entry. |
| `AND-025` | `build build --module app` succeeds; nonexistent module shows Gradle reason. | Positive and negative scratch build entries. |
| `AND-111` | With configured `cov4-android` shut down and no device flag, `build build` compiles only and leaves adb unchanged. | Already a separately controlled source-window compile; do not duplicate in a slice. |
| `AND-112` | `build build --device emulator-5999` fails naming attached devices. | Device-selection negative; does not justify boot/install. |
| `AND-113` | `build install` with `cov4-android` shut down boots it and logs the assigned serial. | Serial Android reservation plus fresh scratch build/install. |
| `AND-143` | `build install --emulator cov4-android --headless --module app` boots, installs, launches. | Serial Android reservation plus fresh scratch build/install. |
| `AND-144` | `build install --platform android` in a copy holding both configs chooses Android and installs. | Scratch dual-config copy plus owned-device build/install. |

Additional Android build-result rows that consume those exact behaviors are `B-A03.2`, `B-A10.2`, `N-02`, `B2-K26`, `B2-K32`, `B2-K54`, `B3-L41`, and `B3-L46`. Cross-platform JSON/install rows are `X-005`, `X-006`, `D2-07`, `D2-08`, `B2-K25`, and `B3-L39`. Where one retained invocation literally covers both keys, evidence may be joined; the keys and clauses remain separate. `N-02`, `B2-K54`, and `AND-111` specifically require compile-only/no-boot proof. `B3-L46` specifically requires its own three install/teardown/reboot persistence cycles and cannot be inferred from an ordinary install.

### CLI actor: parsing/help controls, not application-build authority

These rows name build commands but require refusal/help behavior before compilation: `CLI-005`, `CLI-107`, `CLI-134`, `CLI-165`, `B3-L26-b`, `D2-27`, and `D2-47`. They need no app-build exception. `B3-L29` is mixed: its help/corpus checks are read-only, while literal hidden `build build --headless` and `--emulator X` controls require compile-only runs in an Android scratch copy and proof that the hidden flags change nothing and boot nothing. The row also preserves `--device` only for ABI selection. `B2-K43` is another pre-build flag-refusal row and grants no compile.

## Smallest proposed controller ruling

After root approval, interpret the slice briefs' generic “do not build” as prohibiting CLI compilation, runner compilation, candidate reconstruction, repackaging, artifact substitution, and unlisted/ad-hoc demo builds. It does not cancel a canonical matrix row whose literal command is `build build` or default `build install`.

For only the keys listed above, the owning actor may run the literal row-required application command against a new scratch copy of candidate demo source `84af7581b75134b0e417b254e4317d565f7b73c6`, using the frozen candidate CLI and runner home. Each command must retain candidate/demo hash, scratch-copy manifest, exact argv/cwd/environment, initially absent output/derived-data path where applicable, raw streams, exit, built-product manifest, and before/after source and device proofs. The scratch product is row evidence only. It cannot replace the frozen candidate `.app`, APK, CLI, runner, bundle, or runner-home content.

Negative/parser rows stop at their literal error and never gain permission to build or operate a device. `--no-build --app-file` rows use the frozen candidate `.app`/APK unless the row explicitly binds another row-produced scratch artifact. Install and launch occur only on the actor's allocated `cov4-*` target; no owner device, default simulator, protected AVD, default config, or default runner home is eligible.

## Serial build and load coordination

1. Root schedules all application compilation serially. No iOS or Android app build overlaps Android load-sensitive timing, deadline, cancellation, launch, capture, or cleanup rows. Android load-sensitive work receives a quiet interval before and after compilation.
2. Group build-only commands first where their outputs cannot alter device state. Keep all compile-only/no-boot rows (`AND-111`, `N-02`, `B2-K54`, and the `B3-L29` hidden-flag controls) outside install phases and prove adb/device inventories unchanged.
3. Run install/build-install rows only under the owning platform reservation. Preserve command-specific absent/installed/running/shut-down preconditions; do not preinstall merely to simplify a later row.
4. After a scratch-built product is installed for a literal row, restore the exact frozen candidate demo artifact before ordinary behavior, stock-flow, MCP, selector, lifecycle, or cross-platform comparison rows. Record uninstall/install identities and hash the restored `.app`/APK against the candidate manifest. A scratch artifact must never leak into general slice evidence.
5. Keep D2-08/B2-K25/B3-L39/B4-L71 frozen `--app-file` legs distinct from default build-install legs. Their point is that the supplied artifact skips only compilation; using a newly built unreviewed file would weaken the provenance control.
6. Android rows that require a shut-down AVD, boot transition, teardown, or reboot remain root-serialized around the exact owned AVD/serial. No global adb/simctl teardown, pattern kill, or default-name fallback is introduced.

## Tradeoffs

This ruling adds build time and forces artifact restoration, but it keeps literal application-build coverage possible without reopening product production. Reusing one invocation for compatible aliases reduces load only when every literal clause, input, and actor ownership matches; aggressive reuse risks hiding path, target, launch-state, JSON, or signing requirements. Building all rows independently is simpler to attribute but increases load and makes timing interference more likely. The proposed serial grouping uses fresh output roots and explicit restoration as the narrow middle course.

Root still decides the ruling and exact schedule. No matrix, brief, source, helper, candidate, result, or evidence file was changed by this preparation, and no command/test/build/device/network action or row grading occurred.
